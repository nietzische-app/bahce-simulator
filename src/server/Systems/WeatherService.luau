--!strict
local DataStoreService = game:GetService("DataStoreService")
local WeatherConfig = require(game.ReplicatedStorage.Shared.Config.Weather)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local WeatherService = {}

local STORE_NAME = "MinikBahce_Weather_v1"
local state = {
	eventId = "Sunny",
	startedAt = 0,
	weekKey = "",
}

local function weekKey(now: number): string
	-- ISO-ish week bucket: days since epoch / 7
	return tostring(math.floor(now / (7 * 24 * 3600)))
end

function WeatherService.Init()
	local store = DataStoreService:GetDataStore(STORE_NAME)
	local now = os.time()
	local key = weekKey(now)

	local ok, data = pcall(function()
		return store:GetAsync("Current")
	end)

	if ok and typeof(data) == "table" and data.weekKey == key and typeof(data.eventId) == "string" then
		state.eventId = data.eventId
		state.startedAt = data.startedAt or now
		state.weekKey = key
	else
		local rng = Random.new(tonumber(key) or now)
		local picked = WeatherConfig.PickWeighted(rng)
		state.eventId = picked.id
		state.startedAt = now
		state.weekKey = key
		pcall(function()
			store:SetAsync("Current", {
				eventId = state.eventId,
				startedAt = state.startedAt,
				weekKey = state.weekKey,
			})
		end)
	end

	print("[WeatherService] Active event:", state.eventId)
end

function WeatherService.GetEvent(): Types.WeatherEvent
	return WeatherConfig.Get(state.eventId) or WeatherConfig.All()[1]
end

function WeatherService.GetState()
	local ev = WeatherService.GetEvent()
	return {
		eventId = ev.id,
		displayName = ev.displayName,
		description = ev.description,
		growthMultiplier = ev.growthMultiplier,
		sellMultiplier = ev.sellMultiplier,
		startedAt = state.startedAt,
		weekKey = state.weekKey,
	}
end

function WeatherService.GrowthMultiplier(): number
	return WeatherService.GetEvent().growthMultiplier
end

function WeatherService.SellMultiplier(): number
	return WeatherService.GetEvent().sellMultiplier
end

return WeatherService
