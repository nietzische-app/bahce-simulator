--!strict
--[[
	Rebirth: reset coins/plots progress for permanent sell multiplier + badge.
	Keeps: collection, decor, pets, likes, ownedGamepasses, purchaseHistory.
	Resets: coins, inventory, plants, upgrades, gear, sprinkler, fertilizer,
	        quests, goldenPity, daily streak claim, event currency.
	Cannot be bought with Robux. Requires exact confirm phrase.
]]

local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local Rebirth = require(game.ReplicatedStorage.Shared.Config.Rebirth)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local RebirthService = {}

function RebirthService.Count(data: Types.PlayerData): number
	local n = (data :: any).rebirthCount
	if typeof(n) ~= "number" or n ~= n or n < 0 then
		return 0
	end
	return math.floor(n)
end

function RebirthService.SellMultiplier(data: Types.PlayerData): number
	return Rebirth.SellMultiplier(RebirthService.Count(data))
end

function RebirthService.Can(data: Types.PlayerData): (boolean, string)
	local n = RebirthService.Count(data)
	if n >= Rebirth.MAX_REBIRTHS then
		return false, "Maksimum yeniden doğuşa ulaştın."
	end
	if data.coins < Rebirth.MIN_COINS then
		return false, string.format("Yeniden doğuş için en az %d coin gerekir.", Rebirth.MIN_COINS)
	end
	if data.totalHarvested < Rebirth.MIN_HARVESTED then
		return false, string.format("Yeniden doğuş için en az %d hasat gerekir.", Rebirth.MIN_HARVESTED)
	end
	return true, ""
end

function RebirthService.Perform(data: Types.PlayerData, confirm: string): (boolean, string)
	if confirm ~= Rebirth.CONFIRM_PHRASE then
		return false, "Onay metni hatalı. İptal edildi."
	end
	local ok, why = RebirthService.Can(data)
	if not ok then
		return false, why
	end

	local nextCount = RebirthService.Count(data) + 1
	(data :: any).rebirthCount = nextCount

	-- Reset progress fields; keep collection / decor / pets / likes / gamepasses
	data.coins = GameConfig.STARTING_COINS
	data.inventory = {}
	for seedId, count in pairs(GameConfig.STARTING_SEEDS) do
		data.inventory[seedId] = count
	end
	data.plants = {}
	data.upgrades = { extraSlots = 0, growthSpeedLevel = 0 }
	data.gear = {}
	data.sprinkler = nil
	data.fertilizerCharges = 0
	data.goldenPity = 0
	data.quests = {}
	data.dailyStreak = 0
	data.lastDailyClaim = 0 -- Keep totalHarvested / totalEarned as lifetime stats (kid-safe: progress not erased from boards)
	(data :: any).eventCurrency = {}

	local mult = Rebirth.SellMultiplier(nextCount)
	local badge = Rebirth.BadgeName(nextCount)
	return true,
		string.format(
			"Yeniden doğdun! Rozet: %s — Kalıcı satış çarpanı: ×%.2f. Koleksiyon, dekor ve petlerin sende kaldı.",
			badge,
			mult
		)
end

function RebirthService.Serialize(data: Types.PlayerData)
	local n = RebirthService.Count(data)
	local can, why = RebirthService.Can(data)
	return {
		count = n,
		sellMult = Rebirth.SellMultiplier(n),
		nextSellMult = Rebirth.NextMultiplier(n),
		badge = Rebirth.BadgeName(n),
		minCoins = Rebirth.MIN_COINS,
		minHarvested = Rebirth.MIN_HARVESTED,
		confirmPhrase = Rebirth.CONFIRM_PHRASE,
		can = can,
		why = why,
		max = Rebirth.MAX_REBIRTHS,
	}
end

return RebirthService
