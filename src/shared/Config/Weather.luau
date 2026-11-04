--!strict
local Types = require(script.Parent.Parent.Core.Types)

--[[
	Weekly weather / event catalog (config-driven multipliers).
	One event is active at a time; rolled weekly by the server.
]]
local Events: { Types.WeatherEvent } = {
	{
		id = "Sunny",
		displayName = "Güneşli Günler",
		description = "Bitkiler biraz daha hızlı büyür.",
		growthMultiplier = 1.15,
		sellMultiplier = 1.0,
		durationSeconds = 7 * 24 * 3600,
		weight = 40,
	},
	{
		id = "GentleRain",
		displayName = "Yumuşak Yağmur",
		description = "Hasat satışı biraz daha kazançlı.",
		growthMultiplier = 1.0,
		sellMultiplier = 1.2,
		durationSeconds = 7 * 24 * 3600,
		weight = 30,
	},
	{
		id = "Breezy",
		displayName = "Esintili Hafta",
		description = "Büyüme ve satış dengeli bonus.",
		growthMultiplier = 1.1,
		sellMultiplier = 1.1,
		durationSeconds = 7 * 24 * 3600,
		weight = 20,
	},
	{
		id = "Starlit",
		displayName = "Yıldızlı Gece",
		description = "Nadir bitkiler için güzel bir hafta!",
		growthMultiplier = 1.25,
		sellMultiplier = 1.15,
		durationSeconds = 7 * 24 * 3600,
		weight = 10,
	},
}

local Weather = {}

function Weather.All(): { Types.WeatherEvent }
	return Events
end

function Weather.Get(id: string): Types.WeatherEvent?
	for _, e in Events do
		if e.id == id then
			return e
		end
	end
	return nil
end

function Weather.PickWeighted(rng: Random): Types.WeatherEvent
	local total = 0
	for _, e in Events do
		total += e.weight
	end
	local roll = rng:NextNumber(0, total)
	local acc = 0
	for _, e in Events do
		acc += e.weight
		if roll <= acc then
			return e
		end
	end
	return Events[1]
end

return Weather
