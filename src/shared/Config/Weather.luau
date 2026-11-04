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

--[[
	Short server-wide events (a few minutes). Free for everyone, never purchasable.
	mutationBoosts multiply the base mutation chance.
]]
export type ShortEvent = {
	id: string,
	displayName: string,
	banner: string,
	minDuration: number,
	maxDuration: number,
	weight: number,
	mutationBoosts: { [string]: number },
	color: Color3,
}

Weather.SHORT_EVENT_MIN_GAP = 15 * 60
Weather.SHORT_EVENT_MAX_GAP = 25 * 60

Weather.ShortEvents = {
	{
		id = "Rain",
		displayName = "Yağmur",
		banner = "🌧️ Yağmur yağıyor! Islak ürün şansı x5",
		minDuration = 180,
		maxDuration = 300,
		weight = 50,
		mutationBoosts = { Wet = 5 },
		color = Color3.fromRGB(60, 110, 180),
	},
	{
		id = "Snow",
		displayName = "Kar",
		banner = "❄️ Kar yağıyor! Donmuş ürün şansı x5",
		minDuration = 180,
		maxDuration = 300,
		weight = 30,
		mutationBoosts = { Frozen = 5 },
		color = Color3.fromRGB(150, 190, 220),
	},
	{
		id = "Storm",
		displayName = "Fırtına",
		banner = "⛈️ Fırtına! Altın x2, Gökkuşağı x3 şansı",
		minDuration = 120,
		maxDuration = 240,
		weight = 20,
		mutationBoosts = { Golden = 2, Rainbow = 3, Wet = 2 },
		color = Color3.fromRGB(90, 70, 130),
	},
} :: { ShortEvent }

function Weather.GetShort(id: string?): ShortEvent?
	for _, e in Weather.ShortEvents do
		if e.id == id then
			return e
		end
	end
	return nil
end

-- Returns event, duration seconds
function Weather.PickShortEvent(rng: any): (ShortEvent, number)
	local total = 0
	for _, e in Weather.ShortEvents do
		total += e.weight
	end
	local roll = rng:NextNumber() * total
	local acc = 0
	local picked = Weather.ShortEvents[#Weather.ShortEvents]
	for _, e in Weather.ShortEvents do
		acc += e.weight
		if roll < acc then
			picked = e
			break
		end
	end
	local dur = picked.minDuration + math.floor(rng:NextNumber() * (picked.maxDuration - picked.minDuration))
	return picked, dur
end

function Weather.NextGap(rng: any): number
	return Weather.SHORT_EVENT_MIN_GAP
		+ math.floor(rng:NextNumber() * (Weather.SHORT_EVENT_MAX_GAP - Weather.SHORT_EVENT_MIN_GAP))
end

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
