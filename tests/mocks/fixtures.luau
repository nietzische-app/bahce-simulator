local globals = require("./globals")
local Loader = require("./loader")

local F = {}

F.Random = globals.Random

function F.newData(overrides: { [string]: any }?)
	local d = {
		coins = 0,
		inventory = {},
		plants = {},
		upgrades = { extraSlots = 0, growthSpeedLevel = 0 },
		ownedGamepasses = {},
		purchaseHistory = {},
		lastDailyClaim = 0,
		totalHarvested = 0,
		totalEarned = 0,
		dataVersion = 1,
	}
	for k, v in overrides or {} do
		d[k] = v
	end
	return d
end

-- Loader with server-side Weather/Plot services mocked (no DataStore / Workspace)
function F.serverLoader(weather: { growth: number, sell: number }?)
	local w = weather or { growth = 1, sell = 1 }
	local l = Loader.new()
	l:mock("ServerScriptService.Server.Systems.WeatherService", {
		GrowthMultiplier = function()
			return w.growth
		end,
		SellMultiplier = function()
			return w.sell
		end,
		MutationBoosts = function()
			return (w :: any).boosts or {}
		end,
	})
	l:mock("ServerScriptService.Server.Systems.PlotService", {
		GetOwnedPlots = function()
			return {}
		end,
		SetSlotLocked = function() end,
		UpdatePlantVisual = function() end,
	})
	return l, w
end

return F
