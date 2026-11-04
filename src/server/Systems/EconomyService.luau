--!strict
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local Monetization = require(game.ReplicatedStorage.Shared.Config.Monetization)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)
local Mutations = require(game.ReplicatedStorage.Shared.Config.Mutations)
local WeatherService = require(script.Parent.WeatherService)
local QuestService = require(script.Parent.QuestService)

local EconomyService = {}

function EconomyService.HasGamepass(data: Types.PlayerData, key: string): boolean
	return data.ownedGamepasses[key] == true
end

function EconomyService.SellMultiplier(data: Types.PlayerData): number
	local m = WeatherService.SellMultiplier()
	if EconomyService.HasGamepass(data, Monetization.Gamepasses.DoubleSell.key) then
		m *= 2
	end
	return m
end

function EconomyService.SellAllCrops(data: Types.PlayerData): (boolean, string, number)
	local total = 0
	local sold = 0
	local mult = EconomyService.SellMultiplier(data)
	local keysToClear = {}
	for key, count in pairs(data.inventory) do
		local seedId, mutationId = Mutations.ParseCropKey(key)
		if seedId and count > 0 then
			local seed = Seeds.Get(seedId)
			if seed then
				local gain = math.floor(seed.sellPrice * count * mult * Mutations.Multiplier(mutationId))
				total += gain
				sold += count
				table.insert(keysToClear, key)
			end
		end
	end
	if sold == 0 then
		return false, "Satacak ürünün yok. Önce hasat et!", 0
	end
	for _, key in keysToClear do
		data.inventory[key] = nil
	end
	data.coins += total
	data.totalEarned += total
	QuestService.Track(data, "sell", total)
	return true, string.format("%d ürün satıldı: +%d coin", sold, total), total
end

function EconomyService.BuySeed(data: Types.PlayerData, seedId: string, amount: number): (boolean, string)
	amount = math.floor(amount)
	-- amount ~= amount catches NaN, which would otherwise turn coins into NaN
	if amount ~= amount or amount < 1 or amount > 50 then
		return false, "Geçersiz miktar."
	end
	local seed = Seeds.Get(seedId)
	if not seed then
		return false, "Geçersiz tohum."
	end
	local cost = seed.buyPrice * amount
	if data.coins < cost then
		return false, "Yeterli coin yok."
	end
	data.coins -= cost
	data.inventory[seedId] = (data.inventory[seedId] or 0) + amount
	return true, string.format("%dx %s satın alındı (-%d coin)", amount, seed.displayName, cost)
end

function EconomyService.SlotUpgradeCost(data: Types.PlayerData): number?
	if data.upgrades.extraSlots >= GameConfig.MAX_EXTRA_SLOTS then
		return nil
	end
	return GameConfig.SLOT_UPGRADE_BASE_COST * (data.upgrades.extraSlots + 1)
end

function EconomyService.GrowthUpgradeCost(data: Types.PlayerData): number?
	if data.upgrades.growthSpeedLevel >= GameConfig.GROWTH_SPEED_MAX_LEVEL then
		return nil
	end
	return GameConfig.GROWTH_SPEED_UPGRADE_BASE_COST * (data.upgrades.growthSpeedLevel + 1)
end

function EconomyService.BuyUpgrade(data: Types.PlayerData, upgradeType: string): (boolean, string)
	if upgradeType == "slots" then
		local cost = EconomyService.SlotUpgradeCost(data)
		if not cost then
			return false, "Maksimum yatak sayısına ulaştın."
		end
		if data.coins < cost then
			return false, "Yeterli coin yok."
		end
		data.coins -= cost
		data.upgrades.extraSlots += 1
		return true, "Ekstra yatak açıldı!"
	elseif upgradeType == "growth" then
		local cost = EconomyService.GrowthUpgradeCost(data)
		if not cost then
			return false, "Maksimum büyüme hızına ulaştın."
		end
		if data.coins < cost then
			return false, "Yeterli coin yok."
		end
		data.coins -= cost
		data.upgrades.growthSpeedLevel += 1
		return true, "Büyüme hızı arttı!"
	end
	return false, "Geçersiz yükseltme."
end

function EconomyService.GrantSeedPack(data: Types.PlayerData, rng: Random): string
	local granted = {}
	for _ = 1, Monetization.SeedPackCount do
		local roll = rng:NextNumber()
		local acc = 0
		local picked = Monetization.SeedPackOdds[1].seedId
		for _, entry in Monetization.SeedPackOdds do
			acc += entry.chance
			if roll <= acc then
				picked = entry.seedId
				break
			end
		end
		data.inventory[picked] = (data.inventory[picked] or 0) + 1
		table.insert(granted, picked)
	end
	return "Tohum paketi: " .. table.concat(granted, ", ")
end

return EconomyService
