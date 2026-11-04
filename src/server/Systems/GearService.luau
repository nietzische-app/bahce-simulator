--!strict
--[[
	Server-authoritative gear: buy with coins, use on plants/plot.
	Data: data.gear (gearId -> count), data.sprinkler {startAt,endAt}?, data.fertilizerCharges.
]]

local Gear = require(game.ReplicatedStorage.Shared.Config.Gear)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local GearService = {}

local function ensure(data: Types.PlayerData)
	if typeof(data.gear) ~= "table" then
		data.gear = {}
	end
	if typeof(data.fertilizerCharges) ~= "number" then
		data.fertilizerCharges = 0
	end
end

function GearService.Count(data: Types.PlayerData, gearId: string): number
	ensure(data)
	return (data.gear :: any)[gearId] or 0
end

function GearService.Buy(data: Types.PlayerData, gearId: string, amount: number): (boolean, string)
	ensure(data)
	local g = Gear.Get(gearId)
	if not g then
		return false, "Geçersiz alet."
	end
	if amount ~= amount then
		return false, "Geçersiz miktar."
	end
	amount = math.floor(amount)
	if amount < 1 or amount > Gear.MAX_BUY_PER_REQUEST then
		return false, "Geçersiz miktar."
	end
	local have = GearService.Count(data, gearId)
	if have + amount > Gear.MAX_OWNED then
		return false, "Çantan bu alet için dolu."
	end
	local cost = g.price * amount
	if data.coins < cost then
		return false, "Yeterli coin yok."
	end
	data.coins -= cost
	local bag: any = data.gear
	bag[gearId] = have + amount
	return true, string.format("%s alındı! (×%d)", g.displayName, amount)
end

local function consume(data: Types.PlayerData, gearId: string): boolean
	local have = GearService.Count(data, gearId)
	if have < 1 then
		return false
	end
	local bag: any = data.gear
	bag[gearId] = have - 1
	return true
end

function GearService.SprinklerActive(data: Types.PlayerData, now: number): boolean
	local s = data.sprinkler
	return typeof(s) == "table" and now < s.endAt
end

-- Extra effective growth seconds from sprinkler overlapping [plantedAt, now]
function GearService.SprinklerBonus(data: Types.PlayerData, plantedAt: number, now: number): number
	local s = data.sprinkler
	if typeof(s) ~= "table" then
		return 0
	end
	local a = math.max(plantedAt, s.startAt)
	local b = math.min(now, s.endAt)
	if b <= a then
		return 0
	end
	return (b - a) * (Gear.SPRINKLER_GROWTH - 1)
end

function GearService.MutationBoosts(data: Types.PlayerData, base: { [string]: number }, now: number)
	if not GearService.SprinklerActive(data, now) then
		return base
	end
	local out = table.clone(base)
	out.Wet = (out.Wet or 1) * Gear.SPRINKLER_WET_BOOST
	return out
end

-- getRemaining(plant) -> (ready, remainingSeconds)
function GearService.Use(
	data: Types.PlayerData,
	gearId: string,
	slotIndex: number?,
	now: number,
	findPlant: (number) -> any,
	getRemaining: (any) -> (boolean, number)
): (boolean, string)
	ensure(data)
	local g = Gear.Get(gearId)
	if not g then
		return false, "Geçersiz alet."
	end
	if GearService.Count(data, gearId) < 1 then
		return false, "Bu aletten hiç yok. Dükkândan alabilirsin."
	end
	if gearId == "WateringCan" then
		if typeof(slotIndex) ~= "number" or slotIndex ~= slotIndex then
			return false, "Önce bir bitki seç."
		end
		local plant = findPlant(slotIndex)
		if not plant then
			return false, "Bu yatakta bitki yok."
		end
		if plant.watered then
			return false, "Bu bitki zaten sulandı."
		end
		local ready, remaining = getRemaining(plant)
		if ready then
			return false, "Bitki zaten olgun, hasat edebilirsin!"
		end
		consume(data, gearId)
		plant.plantedAt -= math.ceil(remaining * (1 - Gear.WATERING_REMAINING_FACTOR))
		plant.watered = true
		return true, "Bitki sulandı! Daha hızlı büyüyecek."
	elseif gearId == "Sprinkler" then
		if GearService.SprinklerActive(data, now) then
			return false, "Sprinkler zaten çalışıyor."
		end
		consume(data, gearId)
		data.sprinkler = { startAt = now, endAt = now + Gear.SPRINKLER_SECONDS }
		return true, "Sprinkler kuruldu! 3 dk boyunca bahçen hızlı büyür."
	elseif gearId == "Fertilizer" then
		if (data.fertilizerCharges :: number) >= Gear.MAX_FERTILIZER_CHARGES then
			return false, "Toprak yeterince gübreli."
		end
		consume(data, gearId)
		data.fertilizerCharges = (data.fertilizerCharges :: number) + 1
		return true, "Gübre serpildi! Sonraki hasatta +1 ürün."
	end
	return false, "Geçersiz alet."
end

-- Called on harvest: returns extra crop count
function GearService.ConsumeFertilizer(data: Types.PlayerData): number
	ensure(data)
	if (data.fertilizerCharges :: number) > 0 then
		data.fertilizerCharges = (data.fertilizerCharges :: number) - 1
		return Gear.FERTILIZER_BONUS_CROPS
	end
	return 0
end

function GearService.Serialize(data: Types.PlayerData, now: number)
	ensure(data)
	local s = data.sprinkler
	return {
		owned = data.gear,
		fertilizerCharges = data.fertilizerCharges,
		sprinklerSecondsLeft = if typeof(s) == "table" then math.max(0, s.endAt - now) else 0,
		items = Gear.ListOrdered(),
	}
end

return GearService
