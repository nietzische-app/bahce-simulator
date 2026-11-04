--!strict
--[[
	"Sen yokken..." özeti. Büyüme zaten plantedAt ile çevrimdışı devam eder;
	burada sadece lastSeenAt ile şimdi arasında olgunlaşanlar listelenir.
]]

local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local OfflineService = {}

OfflineService.MIN_AWAY_SECONDS = 60

function OfflineService.FormatDuration(sec: number): string
	sec = math.max(0, math.floor(sec))
	local d = sec // 86400
	local h = (sec % 86400) // 3600
	local m = (sec % 3600) // 60
	if d > 0 then
		return string.format("%d gün %d saat", d, h)
	elseif h > 0 then
		return string.format("%d saat %d dakika", h, m)
	end
	return string.format("%d dakika", math.max(1, m))
end

-- isReadyAt(plant, t) -> boolean. Returns summary or nil (first join / short absence).
function OfflineService.Build(data: Types.PlayerData, now: number, isReadyAt: (any, number) -> boolean)
	local last = data.lastSeenAt
	if typeof(last) ~= "number" or last <= 0 or now - last < OfflineService.MIN_AWAY_SECONDS then
		return nil
	end
	local ripened = {}
	local counts: { [string]: number } = {}
	for _, plant in data.plants do
		local seed = Seeds.Get(plant.seedId)
		if seed and isReadyAt(plant, now) and not isReadyAt(plant, last) then
			if not counts[seed.id] then
				counts[seed.id] = 0
				table.insert(ripened, seed.id)
			end
			counts[seed.id] += 1
		end
	end
	local list = {}
	for _, id in ripened do
		local seed = Seeds.Get(id) :: any
		table.insert(list, { seedId = id, displayName = seed.displayName, count = counts[id] })
	end
	return {
		awaySeconds = now - last,
		awayText = OfflineService.FormatDuration(now - last),
		ripened = list,
		growing = #data.plants,
	}
end

return OfflineService
