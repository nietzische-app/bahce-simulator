--!strict
--[[
	Plant / grow / harvest. Growth works offline via plantedAt timestamps.
]]

local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)
local Mutations = require(game.ReplicatedStorage.Shared.Config.Mutations)
local WeatherService = require(script.Parent.WeatherService)
local PlotService = require(script.Parent.PlotService)
local QuestService = require(script.Parent.QuestService)
local GearService = require(script.Parent.GearService)

local PlantService = {}

-- Server-side RNG (overridable in tests)
PlantService.rng = Random.new() :: any

local function effectiveGrowTime(seed: Types.SeedConfig, upgrades: Types.UpgradeState): number
	local level = math.clamp(upgrades.growthSpeedLevel, 0, GameConfig.GROWTH_SPEED_MAX_LEVEL)
	local speedFactor = 1 - (level * GameConfig.GROWTH_SPEED_PER_LEVEL)
	speedFactor = math.max(0.4, speedFactor)
	local weather = WeatherService.GrowthMultiplier()
	-- Higher weather multiplier = faster growth => divide time
	return seed.growTimeSeconds * speedFactor / weather
end

function PlantService.MaxSlots(data: Types.PlayerData): number
	return GameConfig.BASE_PLOT_SLOTS + math.clamp(data.upgrades.extraSlots, 0, GameConfig.MAX_EXTRA_SLOTS)
end

function PlantService.FindPlant(data: Types.PlayerData, slotIndex: number): (number?, Types.PlantInstance?)
	for i, plant in data.plants do
		if plant.slotIndex == slotIndex then
			return i, plant
		end
	end
	return nil, nil
end

function PlantService.GetProgress(plant: Types.PlantInstance, data: Types.PlayerData): (number, boolean, number)
	local seed = Seeds.Get(plant.seedId)
	if not seed then
		return 0, false, 0
	end
	local need = effectiveGrowTime(seed, data.upgrades)
	local now = os.time()
	local elapsed = now - plant.plantedAt + GearService.SprinklerBonus(data, plant.plantedAt, now)
	local progress = math.clamp(elapsed / need, 0, 1)
	local ready = elapsed >= need
	local remaining = math.max(0, need - elapsed)
	return progress, ready, remaining
end

function PlantService.Plant(data: Types.PlayerData, seedId: string, slotIndex: number): (boolean, string)
	local seed = Seeds.Get(seedId)
	if not seed then
		return false, "Geçersiz tohum."
	end
	local maxSlots = PlantService.MaxSlots(data)
	-- Reject NaN / non-integer slots (NaN slips past range checks and eats a seed)
	if slotIndex ~= slotIndex or slotIndex % 1 ~= 0 or slotIndex < 1 or slotIndex > maxSlots then
		return false, "Bu yatak kilitli veya yok."
	end
	local _, existing = PlantService.FindPlant(data, slotIndex)
	if existing then
		return false, "Bu yatakta zaten bitki var."
	end
	local count = data.inventory[seedId] or 0
	if count < 1 then
		return false, "Envanterinde bu tohum yok."
	end
	data.inventory[seedId] = count - 1
	table.insert(data.plants, {
		seedId = seedId,
		plantedAt = os.time(),
		slotIndex = slotIndex,
	})
	QuestService.Track(data, "plant", 1)
	return true, seed.displayName .. " ekildi!"
end

function PlantService.Harvest(data: Types.PlayerData, slotIndex: number): (boolean, string, number?)
	local idx, plant = PlantService.FindPlant(data, slotIndex)
	if not idx or not plant then
		return false, "Bu yatakta bitki yok.", nil
	end
	local seed = Seeds.Get(plant.seedId)
	if not seed then
		table.remove(data.plants, idx)
		return false, "Bilinmeyen bitki temizlendi.", nil
	end
	local _, ready = PlantService.GetProgress(plant, data)
	if not ready then
		return false, "Bitki henüz olgun değil.", nil
	end
	table.remove(data.plants, idx)
	data.totalHarvested += 1
	local boosts = if WeatherService.MutationBoosts then WeatherService.MutationBoosts() else {}
	boosts = GearService.MutationBoosts(data, boosts, os.time())
	local mutationId, pity = Mutations.Roll(PlantService.rng, boosts, data.goldenPity)
	data.goldenPity = pity
	local cropKey = Mutations.CropKey(seed.id, mutationId)
	local bonus = GearService.ConsumeFertilizer(data)
	data.inventory[cropKey] = (data.inventory[cropKey] or 0) + 1 + bonus
	local mut = Mutations.Get(mutationId)
	QuestService.Track(data, "harvest", 1)
	local extra = if bonus > 0 then string.format(" Gübre: +%d ürün!", bonus) else ""
	if mut then
		QuestService.Track(data, "mutated", 1)
		return true,
			string.format(
				"%s %s hasat edildi! (x%d değer)%s",
				mut.displayName,
				seed.displayName,
				mut.multiplier,
				extra
			),
			seed.sellPrice * mut.multiplier
	end
	return true, seed.displayName .. " hasat edildi!" .. extra, seed.sellPrice
end

function PlantService.InstantGrowAll(data: Types.PlayerData)
	local now = os.time()
	for _, plant in data.plants do
		local seed = Seeds.Get(plant.seedId)
		if seed then
			plant.plantedAt = now - math.ceil(effectiveGrowTime(seed, data.upgrades))
		end
	end
end

function PlantService.AutoHarvestReady(data: Types.PlayerData): number
	local harvested = 0
	local slots = {}
	for _, plant in data.plants do
		table.insert(slots, plant.slotIndex)
	end
	for _, slotIndex in slots do
		local ok = PlantService.Harvest(data, slotIndex)
		if ok then
			harvested += 1
		end
	end
	return harvested
end

function PlantService.SyncVisuals(player: Player, data: Types.PlayerData)
	local owned = PlotService.GetOwnedPlots(player.UserId)
	local primary = owned[1]
	if not primary then
		return
	end
	local maxSlots = PlantService.MaxSlots(data)
	for s = 1, GameConfig.BASE_PLOT_SLOTS + GameConfig.MAX_EXTRA_SLOTS do
		PlotService.SetSlotLocked(primary, s, s > maxSlots)
	end
	if PlotService.SetSprinkler then
		PlotService.SetSprinkler(primary, GearService.SprinklerActive(data, os.time()))
	end
	-- Clear then draw
	for s = 1, GameConfig.BASE_PLOT_SLOTS + GameConfig.MAX_EXTRA_SLOTS do
		local _, plant = PlantService.FindPlant(data, s)
		if plant then
			local seed = Seeds.Get(plant.seedId)
			if seed then
				local progress, ready = PlantService.GetProgress(plant, data)
				PlotService.UpdatePlantVisual(primary, s, seed.color, progress, ready, seed.id)
			end
		else
			PlotService.UpdatePlantVisual(primary, s, nil)
		end
	end
end

function PlantService.SerializePlants(data: Types.PlayerData)
	local list = {}
	for _, plant in data.plants do
		local progress, ready, remaining = PlantService.GetProgress(plant, data)
		table.insert(list, {
			seedId = plant.seedId,
			slotIndex = plant.slotIndex,
			plantedAt = plant.plantedAt,
			progress = progress,
			ready = ready,
			remaining = remaining,
		})
	end
	return list
end

return PlantService
