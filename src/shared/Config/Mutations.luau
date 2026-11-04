--!strict
--[[
	Crop mutations: rolled server-side at harvest. Odds are public (shown in UI).
	Inventory key format: "crop:<seedId>" (normal, backward compatible) or
	"crop:<seedId>:<mutationId>" (mutated).
]]

export type Mutation = {
	id: string,
	displayName: string,
	multiplier: number,
	chance: number, -- base chance per harvest (0..1)
	color: Color3,
}

local Mutations = {}

-- Ordered rarest first (roll checks in this order)
Mutations.List = {
	{
		id = "Rainbow",
		displayName = "Gökkuşağı",
		multiplier = 50,
		chance = 0.001,
		color = Color3.fromRGB(200, 120, 255),
	},
	{ id = "Golden", displayName = "Altın", multiplier = 20, chance = 0.005, color = Color3.fromRGB(255, 200, 40) },
	{ id = "Frozen", displayName = "Donmuş", multiplier = 10, chance = 0.01, color = Color3.fromRGB(150, 220, 255) },
	{ id = "Wet", displayName = "Islak", multiplier = 2, chance = 0.08, color = Color3.fromRGB(80, 140, 220) },
} :: { Mutation }

-- Golden pity: after this many harvests without Golden/Rainbow, next harvest is Golden.
Mutations.GOLDEN_PITY = 250
-- Never let total mutation chance exceed this (keeps normal crops common).
Mutations.MAX_TOTAL_CHANCE = 0.6

function Mutations.Get(id: string?): Mutation?
	if not id then
		return nil
	end
	for _, m in Mutations.List do
		if m.id == id then
			return m
		end
	end
	return nil
end

function Mutations.Multiplier(id: string?): number
	local m = Mutations.Get(id)
	return if m then m.multiplier else 1
end

-- Effective chances after weather boosts (boosts: mutationId -> factor)
function Mutations.EffectiveChances(boosts: { [string]: number }?): { [string]: number }
	local out = {}
	local total = 0
	for _, m in Mutations.List do
		local f = if boosts and boosts[m.id] then boosts[m.id] else 1
		out[m.id] = m.chance * f
		total += out[m.id]
	end
	if total > Mutations.MAX_TOTAL_CHANCE then
		local scale = Mutations.MAX_TOTAL_CHANCE / total
		for k, v in out do
			out[k] = v * scale
		end
	end
	return out
end

--[[
	Roll a mutation. Returns mutationId or nil, plus the new pity counter.
	rng must provide NextNumber() in [0,1).
]]
function Mutations.Roll(rng: any, boosts: { [string]: number }?, pity: number?): (string?, number)
	local p = (pity or 0) + 1
	if p >= Mutations.GOLDEN_PITY then
		return "Golden", 0
	end
	local chances = Mutations.EffectiveChances(boosts)
	local roll = rng:NextNumber()
	local acc = 0
	for _, m in Mutations.List do
		acc += chances[m.id]
		if roll < acc then
			if m.id == "Golden" or m.id == "Rainbow" then
				return m.id, 0
			end
			return m.id, p
		end
	end
	return nil, p
end

function Mutations.CropKey(seedId: string, mutationId: string?): string
	if mutationId then
		return "crop:" .. seedId .. ":" .. mutationId
	end
	return "crop:" .. seedId
end

-- Parse "crop:<seed>[:<mut>]" -> seedId, mutationId?  (nil if not a crop key)
function Mutations.ParseCropKey(key: string): (string?, string?)
	if string.sub(key, 1, 5) ~= "crop:" then
		return nil, nil
	end
	local rest = string.sub(key, 6)
	local seedId, mut = string.match(rest, "^([^:]+):([^:]+)$")
	if seedId then
		return seedId, mut
	end
	return rest, nil
end

function Mutations.FormatOdds(boosts: { [string]: number }?): string
	local chances = Mutations.EffectiveChances(boosts)
	local parts = {}
	for _, m in Mutations.List do
		table.insert(parts, string.format("%s x%d: %%%.2f", m.displayName, m.multiplier, chances[m.id] * 100))
	end
	return table.concat(parts, " | ")
end

return Mutations
