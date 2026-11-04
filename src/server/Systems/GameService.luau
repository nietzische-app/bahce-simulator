--!strict
--[[
	Wires remotes, rate limits, player lifecycle, and state replication.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Monetization = require(game.ReplicatedStorage.Shared.Config.Monetization)
local RateLimiter = require(game.ReplicatedStorage.Shared.Core.RateLimiter)

local Remotes = require(script.Parent.Parent.Core.Remotes)
local ProfileStore = require(script.Parent.Parent.Core.ProfileStore)

local PlotService = require(script.Parent.PlotService)
local PlantService = require(script.Parent.PlantService)
local EconomyService = require(script.Parent.EconomyService)
local WeatherService = require(script.Parent.WeatherService)
local Mutations = require(game.ReplicatedStorage.Shared.Config.Mutations)
local LeaderboardService = require(script.Parent.LeaderboardService)
local DailyRewardService = require(script.Parent.DailyRewardService)
local MonetizationService = require(script.Parent.MonetizationService)
local StockService = require(script.Parent.StockService)
local QuestService = require(script.Parent.QuestService)
local GearService = require(script.Parent.GearService)

local GameService = {}

local store = ProfileStore.new(GameConfig.DATA_STORE_NAME)
local limiter = RateLimiter.new(8, 4) -- burst 8, refill 4/sec

local function notify(player: Player, message: string, kind: string?)
	Remotes.Event("Notify"):FireClient(player, {
		message = message,
		kind = kind or "info",
	})
end

local function buildState(player: Player, data: any)
	return {
		coins = data.coins,
		inventory = data.inventory,
		plants = PlantService.SerializePlants(data),
		upgrades = data.upgrades,
		ownedGamepasses = data.ownedGamepasses,
		maxSlots = PlantService.MaxSlots(data),
		canClaimDaily = DailyRewardService.CanClaim(data),
		daily = DailyRewardService.Serialize(data),
		quests = QuestService.Serialize(data),
		stock = StockService.Snapshot(player.UserId, os.time()),
		gear = GearService.Serialize(data, os.time()),
		weather = WeatherService.GetState(),
		seeds = Seeds.ListOrdered(),
		shop = {
			slotUpgradeCost = EconomyService.SlotUpgradeCost(data),
			growthUpgradeCost = EconomyService.GrowthUpgradeCost(data),
			gamepasses = Monetization.Gamepasses,
			products = Monetization.DevProducts,
			seedPackOdds = Monetization.FormatSeedPackOdds(),
			mutationOdds = Mutations.FormatOdds(WeatherService.MutationBoosts()),
			mutationPity = Mutations.GOLDEN_PITY - (data.goldenPity or 0),
		},
		plotIndexes = (function()
			local idxs = {}
			for _, p in PlotService.GetOwnedPlots(player.UserId) do
				table.insert(idxs, p.index)
			end
			return idxs
		end)(),
		displayName = GameConfig.DISPLAY_NAME,
	}
end

local function pushState(player: Player)
	local profile = store:Get(player)
	if not profile then
		return
	end
	LeaderboardService.EnsureLeaderstats(player, profile.Data.coins, profile.Data.totalHarvested)
	LeaderboardService.SetCoins(player, profile.Data.coins)
	LeaderboardService.SetHarvested(player, profile.Data.totalHarvested)
	PlantService.SyncVisuals(player, profile.Data)
	Remotes.Event("StateUpdate"):FireClient(player, buildState(player, profile.Data))
end

local function withProfile(player: Player, action: string, fn: (any) -> ())
	if not limiter:Allow(player, action) then
		notify(player, "Çok hızlı tıkladın, biraz bekle.", "warn")
		return
	end
	local profile = store:Get(player)
	if not profile then
		notify(player, "Verin yükleniyor…", "warn")
		return
	end
	fn(profile)
end

local function onPlayerAdded(player: Player)
	local profile = store:Load(player)
	if not profile then
		notify(player, "Kayıt yüklenemedi (oturum kilitli olabilir). Yeniden dene.", "error")
		task.wait(2)
		player:Kick("Veri yüklenemedi. Lütfen birkaç saniye sonra tekrar gir.")
		return
	end

	local plot = PlotService.AssignPlot(player.UserId, profile.Data.plotIndex)
	if plot then
		profile.Data.plotIndex = plot.index
		-- Teleport near plot
		task.defer(function()
			local char = player.Character or player.CharacterAdded:Wait()
			local hrp = char:WaitForChild("HumanoidRootPart", 10) :: BasePart?
			if hrp and plot.model.PrimaryPart then
				hrp.CFrame = plot.model.PrimaryPart.CFrame + Vector3.new(0, 5, 14)
			end
		end)
	else
		notify(player, "Boş parsel kalmadı — biraz bekle.", "warn")
	end

	MonetizationService.SyncOwnedGamepasses(player)
	LeaderboardService.EnsureLeaderstats(player, profile.Data.coins, profile.Data.totalHarvested)
	LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
	pushState(player)

	-- Auto-harvest loop for gamepass holders
	task.spawn(function()
		while player.Parent == Players do
			task.wait(GameConfig.AUTO_HARVEST_INTERVAL)
			local p = store:Get(player)
			if not p then
				break
			end
			if EconomyService.HasGamepass(p.Data, Monetization.Gamepasses.AutoHarvest.key) then
				local n = PlantService.AutoHarvestReady(p.Data)
				if n > 0 then
					pushState(player)
				end
			else
				-- Still refresh growth visuals periodically
				PlantService.SyncVisuals(player, p.Data)
			end
		end
	end)
end

local function onPlayerRemoving(player: Player)
	local profile = store:Get(player)
	if profile then
		LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
	end
	PlotService.ReleasePlots(player.UserId)
	store:Release(player)
	limiter:ClearPlayer(player)
	StockService.ClearPlayer(player.UserId)
end

function GameService.Init()
	Remotes.Init()
	PlotService.Init()
	WeatherService.OnChanged(function()
		for _, p in Players:GetPlayers() do
			pushState(p)
		end
	end)
	WeatherService.Init()
	MonetizationService.Init(store, pushState)

	Remotes.Event("RequestState").OnServerEvent:Connect(function(player)
		pushState(player)
	end)

	Remotes.Event("PlantSeed").OnServerEvent:Connect(function(player, seedId, slotIndex)
		if typeof(seedId) ~= "string" or typeof(slotIndex) ~= "number" then
			return
		end
		withProfile(player, "plant", function(profile)
			local ok, msg = PlantService.Plant(profile.Data, seedId, math.floor(slotIndex))
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("Harvest").OnServerEvent:Connect(function(player, slotIndex)
		if typeof(slotIndex) ~= "number" then
			return
		end
		withProfile(player, "harvest", function(profile)
			local ok, msg = PlantService.Harvest(profile.Data, math.floor(slotIndex))
			notify(player, msg, if ok then "ok" else "warn")
			if ok then
				LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
			end
			pushState(player)
		end)
	end)

	Remotes.Event("SellAll").OnServerEvent:Connect(function(player)
		withProfile(player, "sell", function(profile)
			local ok, msg = EconomyService.SellAllCrops(profile.Data)
			notify(player, msg, if ok then "ok" else "warn")
			LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
			pushState(player)
		end)
	end)

	Remotes.Event("BuySeed").OnServerEvent:Connect(function(player, seedId, amount)
		if typeof(seedId) ~= "string" then
			return
		end
		if typeof(amount) ~= "number" then
			amount = 1
		end
		withProfile(player, "buy", function(profile)
			local ok, msg = StockService.Buy(profile.Data, player.UserId, seedId, amount, EconomyService.BuySeed)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("BuyUpgrade").OnServerEvent:Connect(function(player, upgradeType)
		if typeof(upgradeType) ~= "string" then
			return
		end
		withProfile(player, "upgrade", function(profile)
			local ok, msg = EconomyService.BuyUpgrade(profile.Data, upgradeType)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("BuyGear").OnServerEvent:Connect(function(player, gearId, amount)
		if typeof(gearId) ~= "string" then
			return
		end
		if typeof(amount) ~= "number" then
			amount = 1
		end
		withProfile(player, "gear", function(profile)
			local ok, msg = GearService.Buy(profile.Data, gearId, amount)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("UseGear").OnServerEvent:Connect(function(player, gearId, slotIndex)
		if typeof(gearId) ~= "string" or (slotIndex ~= nil and typeof(slotIndex) ~= "number") then
			return
		end
		withProfile(player, "gear", function(profile)
			local data = profile.Data
			local ok, msg = GearService.Use(
				data,
				gearId,
				if slotIndex then math.floor(slotIndex) else nil,
				os.time(),
				function(s)
					local _, plant = PlantService.FindPlant(data, s)
					return plant
				end,
				function(plant)
					local _, ready, remaining = PlantService.GetProgress(plant, data)
					return ready, remaining
				end
			)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("ClaimDaily").OnServerEvent:Connect(function(player)
		withProfile(player, "daily", function(profile)
			local ok, msg = DailyRewardService.Claim(profile.Data)
			notify(player, msg, if ok then "ok" else "warn")
			LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
			pushState(player)
		end)
	end)

	Remotes.Event("ClaimQuest").OnServerEvent:Connect(function(player, index)
		if typeof(index) ~= "number" then
			return
		end
		withProfile(player, "quest", function(profile)
			local ok, msg = QuestService.Claim(profile.Data, index)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("PromptGamepass").OnServerEvent:Connect(function(player, key)
		if typeof(key) ~= "string" then
			return
		end
		if not limiter:Allow(player, "prompt") then
			return
		end
		local gp = Monetization.Gamepasses[key]
		if not gp or gp.gamePassId == 0 then
			notify(player, "Bu gamepass henüz yapılandırılmadı (ID yer tutucu).", "warn")
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, gp.gamePassId)
	end)

	Remotes.Event("PromptProduct").OnServerEvent:Connect(function(player, key)
		if typeof(key) ~= "string" then
			return
		end
		if not limiter:Allow(player, "prompt") then
			return
		end
		local prod = Monetization.DevProducts[key]
		if not prod or prod.productId == 0 then
			notify(player, "Bu ürün henüz yapılandırılmadı (ID yer tutucu).", "warn")
			return
		end
		MarketplaceService:PromptProductPurchase(player, prod.productId)
	end)

	Remotes.Function("GetLeaderboard").OnServerInvoke = function(player)
		if not limiter:Allow(player, "leaderboard", 2) then
			return {}
		end
		return LeaderboardService.GetTop(10)
	end

	Players.PlayerAdded:Connect(onPlayerAdded)
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	for _, p in Players:GetPlayers() do
		task.spawn(onPlayerAdded, p)
	end

	-- Free shop restock every Shop.RESTOCK_SECONDS (no Robux restock)
	StockService.Tick(os.time())
	task.spawn(function()
		while true do
			task.wait(1)
			if StockService.Tick(os.time()) then
				for _, p in Players:GetPlayers() do
					pushState(p)
				end
			end
		end
	end)

	-- Periodic leaderboard refresh for online players
	task.spawn(function()
		while true do
			task.wait(GameConfig.LEADERBOARD_UPDATE_SECONDS)
			for _, player in Players:GetPlayers() do
				local profile = store:Get(player)
				if profile then
					LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
				end
			end
		end
	end)

	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			onPlayerRemoving(player)
		end
		task.wait(2)
	end)

	print("[GameService] Minik Bahçe sunucusu hazır")
end

return GameService
