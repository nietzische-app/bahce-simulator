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
local CollectionService = require(script.Parent.CollectionService)
local OfflineService = require(script.Parent.OfflineService)
local DecorService = require(script.Parent.DecorService)
local LikeService = require(script.Parent.LikeService)
local Social = require(game.ReplicatedStorage.Shared.Config.Social)

local GameService = {}

local store = ProfileStore.new(GameConfig.DATA_STORE_NAME)
local limiter = RateLimiter.new(8, 4) -- burst 8, refill 4/sec
local socialLimiter = RateLimiter.new(3, 0.5) -- ziyaret/beğeni/tepki: burst 3, 1 per 2s
local lastSocial: { [string]: number } = {}

local function cooldownOk(player: Player, action: string, seconds: number): boolean
	local key = tostring(player.UserId) .. ":" .. action
	local now = os.clock()
	if lastSocial[key] and now - lastSocial[key] < seconds then
		return false
	end
	lastSocial[key] = now
	return true
end

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
		collection = CollectionService.Serialize(data),
		decor = DecorService.Serialize(data),
		likes = LikeService.Likes(data),
		reactions = Social.REACTIONS,
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
	local plot = PlotService.GetPlotForUser(player.UserId)
	if plot then
		PlotService.RenderDecor(plot, DecorService.Ensure(profile.Data).placed)
		PlotService.SetLikes(plot, LikeService.Likes(profile.Data))
	end
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local lv = ls:FindFirstChild("Beğeni") :: IntValue?
		if not lv then
			lv = Instance.new("IntValue")
			lv.Name = "Beğeni"
			lv.Parent = ls
		end
		lv.Value = LikeService.Likes(profile.Data)
	end
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

	-- Offline summary uses the previous lastSeenAt, before any save overwrites it
	local now = os.time()
	local data = profile.Data
	local summary = OfflineService.Build(data, now, function(plant, t)
		return PlantService.IsReadyAt(plant, data, t)
	end)
	data.lastSeenAt = now
	CollectionService.Ensure(data)

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
	if summary then
		Remotes.Event("OfflineSummary"):FireClient(player, summary)
	end

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
	socialLimiter:ClearPlayer(player)
	local prefix = tostring(player.UserId) .. ":"
	for k in lastSocial do
		if string.sub(k, 1, #prefix) == prefix then
			lastSocial[k] = nil
		end
	end
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

	Remotes.Event("ClaimCollection").OnServerEvent:Connect(function(player, seedId)
		if typeof(seedId) ~= "string" or #seedId > 40 then
			return
		end
		withProfile(player, "collection", function(profile)
			local ok, msg = CollectionService.ClaimRow(profile.Data, seedId)
			notify(player, msg, if ok then "ok" else "warn")
			if ok then
				LeaderboardService.UpdateCoins(player.UserId, profile.Data.coins)
			end
			pushState(player)
		end)
	end)

	-- Dekor (kozmetik, coin ile). Konum sunucuda yuva indeksiyle doğrulanır: sadece kendi parseli.
	Remotes.Event("BuyDecor").OnServerEvent:Connect(function(player, id, amount)
		if typeof(id) ~= "string" or #id > 40 then
			return
		end
		withProfile(player, "decor", function(profile)
			local ok, msg = DecorService.Buy(profile.Data, id, if typeof(amount) == "number" then amount else 1)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("PlaceDecor").OnServerEvent:Connect(function(player, id, slot, rot)
		if typeof(id) ~= "string" or #id > 40 or typeof(slot) ~= "number" then
			return
		end
		withProfile(player, "decor", function(profile)
			local ok, msg = DecorService.Place(profile.Data, id, slot, if typeof(rot) == "number" then rot else nil)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("RemoveDecor").OnServerEvent:Connect(function(player, slot)
		if typeof(slot) ~= "number" then
			return
		end
		withProfile(player, "decor", function(profile)
			local ok, msg = DecorService.Remove(profile.Data, slot)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	Remotes.Event("MoveDecor").OnServerEvent:Connect(function(player, fromSlot, toSlot, rot)
		if typeof(fromSlot) ~= "number" or typeof(toSlot) ~= "number" then
			return
		end
		withProfile(player, "decor", function(profile)
			local ok, msg =
				DecorService.Move(profile.Data, fromSlot, toSlot, if typeof(rot) == "number" then rot else nil)
			notify(player, msg, if ok then "ok" else "warn")
			pushState(player)
		end)
	end)

	-- Bahçeler: aynı sunucudaki oyuncular. Ziyaret sadece ışınlar; başkasının parselinde
	-- ekme/hasat/dekor işlemleri yalnızca kendi profiline yazdığı için etkisizdir.
	Remotes.Function("ListGardens").OnServerInvoke = function(player)
		if not socialLimiter:Allow(player, "list") then
			return {}
		end
		local me = store:Get(player)
		local now = os.time()
		local out = {}
		for _, other in Players:GetPlayers() do
			local prof = store:Get(other)
			local plot = PlotService.GetPlotForUser(other.UserId)
			if prof and plot then
				table.insert(out, {
					userId = other.UserId,
					name = other.DisplayName,
					plotIndex = plot.index,
					likes = LikeService.Likes(prof.Data),
					isMe = other == player,
					likedToday = if me then LikeService.LikedToday(me.Data, other.UserId, now) else false,
				})
			end
		end
		table.sort(out, function(a, b)
			return a.likes > b.likes
		end)
		return out
	end

	local function teleportTo(player: Player, userId: number): boolean
		local plot = PlotService.GetPlotForUser(userId)
		local char = player.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not plot or not hrp or not plot.model.PrimaryPart then
			return false
		end
		hrp.CFrame = plot.model.PrimaryPart.CFrame + Vector3.new(0, 5, 14)
		return true
	end

	Remotes.Event("VisitGarden").OnServerEvent:Connect(function(player, userId)
		if typeof(userId) ~= "number" or userId ~= userId then
			return
		end
		if not cooldownOk(player, "visit", Social.VISIT_COOLDOWN_SECONDS) then
			notify(player, "Biraz bekle, sonra ziyaret et.", "warn")
			return
		end
		local target = Players:GetPlayerByUserId(userId)
		if not target or not store:Get(target) then
			notify(player, "Bu bahçe artık burada değil.", "warn")
			return
		end
		if teleportTo(player, userId) then
			notify(player, target.DisplayName .. " bahçesine hoş geldin! 🌸", "ok")
		end
	end)

	Remotes.Event("ReturnHome").OnServerEvent:Connect(function(player)
		if not cooldownOk(player, "visit", Social.VISIT_COOLDOWN_SECONDS) then
			return
		end
		teleportTo(player, player.UserId)
	end)

	Remotes.Event("LikeGarden").OnServerEvent:Connect(function(player, userId)
		if typeof(userId) ~= "number" or userId ~= userId then
			return
		end
		if not socialLimiter:Allow(player, "like") then
			notify(player, "Çok hızlı! Biraz bekle.", "warn")
			return
		end
		local target = Players:GetPlayerByUserId(userId)
		local me = store:Get(player)
		local them = target and store:Get(target)
		if not target or not me or not them then
			notify(player, "Bu bahçe artık burada değil.", "warn")
			return
		end
		local ok, msg = LikeService.Like(me.Data, them.Data, player.UserId, userId, os.time())
		notify(player, msg, if ok then "ok" else "warn")
		if ok then
			notify(target, player.DisplayName .. " bahçeni beğendi! 💚", "ok")
			local plot = PlotService.GetPlotForUser(userId)
			if plot then
				PlotService.ShowReaction(plot, "💚")
			end
			pushState(target)
		end
	end)

	Remotes.Event("SendReaction").OnServerEvent:Connect(function(player, userId, emoji)
		if typeof(userId) ~= "number" or not Social.IsReaction(emoji) or userId == player.UserId then
			return
		end
		if not cooldownOk(player, "react", Social.REACTION_COOLDOWN_SECONDS) then
			return
		end
		local target = Players:GetPlayerByUserId(userId)
		local plot = PlotService.GetPlotForUser(userId)
		if target and plot then
			PlotService.ShowReaction(plot, emoji)
			notify(target, player.DisplayName .. " bahçene " .. emoji .. " bıraktı!", "info")
		end
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
