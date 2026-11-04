--!strict
--[[
	MarketplaceService hooks. ProcessReceipt is idempotent via purchaseHistory.
	Gamepass IDs are placeholders (0) until set in config.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Monetization = require(game.ReplicatedStorage.Shared.Config.Monetization)
local EconomyService = require(script.Parent.EconomyService)
local PlantService = require(script.Parent.PlantService)
local PlotService = require(script.Parent.PlotService)

local MonetizationService = {}

local profileStoreRef: any = nil
local pushState: ((Player) -> ())? = nil
local rng = Random.new()

function MonetizationService.Init(profileStore: any, pushStateFn: (Player) -> ())
	profileStoreRef = profileStore
	pushState = pushStateFn

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return MonetizationService.ProcessReceipt(receiptInfo)
	end

	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
		if not wasPurchased then
			return
		end
		local def = Monetization.GamepassById(passId)
		if def then
			MonetizationService.GrantGamepass(player, def.key)
		end
	end)

	Players.PlayerAdded:Connect(function(player)
		task.defer(function()
			MonetizationService.SyncOwnedGamepasses(player)
		end)
	end)
end

function MonetizationService.GrantGamepass(player: Player, key: string)
	local profile = profileStoreRef and profileStoreRef:Get(player)
	if not profile then
		return
	end
	profile.Data.ownedGamepasses[key] = true
	if key == Monetization.Gamepasses.ExtraPlot.key then
		PlotService.AssignExtraPlot(player.UserId)
	end
	if pushState then
		pushState(player)
	end
end

function MonetizationService.SyncOwnedGamepasses(player: Player)
	local profile = profileStoreRef and profileStoreRef:Get(player)
	if not profile then
		return
	end
	for _, gp in pairs(Monetization.Gamepasses) do
		if gp.gamePassId ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, gp.gamePassId)
			end)
			if ok and owns then
				profile.Data.ownedGamepasses[gp.key] = true
				if gp.key == Monetization.Gamepasses.ExtraPlot.key then
					local owned = PlotService.GetOwnedPlots(player.UserId)
					if #owned < 2 then
						PlotService.AssignExtraPlot(player.UserId)
					end
				end
			end
		end
	end
end

function MonetizationService.ProcessReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- Player left; retry later
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local profile = profileStoreRef and profileStoreRef:Get(player)
	if not profile then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local purchaseId = tostring(receiptInfo.PurchaseId)
	if profileStoreRef:HasPurchase(profile, purchaseId) then
		-- Idempotent: already granted
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = receiptInfo.ProductId
	local def = Monetization.ProductById(productId)

	-- If IDs still placeholders (0), refuse grant to avoid mis-attribution
	if not def then
		warn("[Monetization] Unknown productId", productId, "- set Monetization.luau placeholders")
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if def.key == "InstantGrow" then
		PlantService.InstantGrowAll(profile.Data)
	elseif def.key == "SeedPack" then
		EconomyService.GrantSeedPack(profile.Data, rng)
	else
		warn("[Monetization] Unhandled product key", def.key)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	profileStoreRef:RecordPurchase(profile, purchaseId, productId)
	profileStoreRef:Save(profile, false)
	PlantService.SyncVisuals(player, profile.Data)
	if pushState then
		pushState(player)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return MonetizationService
