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

-- Short server-wide event (not persisted; per-server)
local short = {
	eventId = nil :: string?,
	endsAt = 0,
}
local listeners: { () -> () } = {}

local function fireChanged()
	for _, cb in listeners do
		task.spawn(cb)
	end
end

function WeatherService.OnChanged(cb: () -> ())
	table.insert(listeners, cb)
end

-- Exposed for tests / Studio debugging (server only)
function WeatherService.StartShortEvent(id: string, duration: number, now: number?)
	if not WeatherConfig.GetShort(id) then
		return false
	end
	short.eventId = id
	short.endsAt = (now or os.time()) + duration
	fireChanged()
	return true
end

function WeatherService.EndShortEvent()
	short.eventId = nil
	short.endsAt = 0
	fireChanged()
end

function WeatherService.GetShortEvent(now: number?): WeatherConfig.ShortEvent?
	if short.eventId and (now or os.time()) < short.endsAt then
		return WeatherConfig.GetShort(short.eventId)
	end
	return nil
end

function WeatherService.MutationBoosts(now: number?): { [string]: number }
	local ev = WeatherService.GetShortEvent(now)
	return if ev then ev.mutationBoosts else {}
end

local function shortEventLoop()
	local rng = Random.new()
	while true do
		task.wait(WeatherConfig.NextGap(rng))
		local ev, dur = WeatherConfig.PickShortEvent(rng)
		WeatherService.StartShortEvent(ev.id, dur)
		print("[WeatherService] Short event:", ev.id, dur)
		task.wait(dur)
		WeatherService.EndShortEvent()
	end
end

local function weekKey(now: number): string
	-- ISO-ish week bucket: days since epoch / 7
	return tostring(math.floor(now / (7 * 24 * 3600)))
end

function WeatherService.Init()
	local store = require(script.Parent.Parent.Core.SafeDataStore).Get(STORE_NAME)
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
	task.spawn(shortEventLoop)
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
		short = (function()
			local se = WeatherService.GetShortEvent()
			if not se then
				return nil
			end
			return {
				id = se.id,
				displayName = se.displayName,
				banner = se.banner,
				endsAt = short.endsAt,
				color = se.color,
			}
		end)(),
	}
end

function WeatherService.GrowthMultiplier(): number
	return WeatherService.GetEvent().growthMultiplier
end

function WeatherService.SellMultiplier(): number
	return WeatherService.GetEvent().sellMultiplier
end

return WeatherService
