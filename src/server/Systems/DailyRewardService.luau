--!strict
--[[
	7-day streak calendar. Backward compatible: old saves only have
	lastDailyClaim; a missing dailyStreak counts as 0.
	Missing a day gently restarts at day 1 (nothing is taken away).
]]
local DailyCalendar = require(game.ReplicatedStorage.Shared.Config.DailyCalendar)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local DailyRewardService = {}

local function dayIndex(now: number): number
	return math.floor(now / 86400)
end

function DailyRewardService.CanClaim(data: Types.PlayerData, now: number?): boolean
	return dayIndex(now or os.time()) > dayIndex(data.lastDailyClaim or 0)
end

-- Which calendar day (1..7) the next claim would grant
function DailyRewardService.NextDay(data: Types.PlayerData, now: number?): number
	local today = dayIndex(now or os.time())
	local last = dayIndex(data.lastDailyClaim or 0)
	local streak = data.dailyStreak or 0
	if today == last then
		return streak % #DailyCalendar.Days + 1 -- tomorrow's
	end
	if today == last + 1 and streak > 0 then
		return streak % #DailyCalendar.Days + 1
	end
	return 1
end

function DailyRewardService.Claim(data: Types.PlayerData, now: number?): (boolean, string)
	local t = now or os.time()
	if not DailyRewardService.CanClaim(data, t) then
		return false, "Bugünkü ödülü zaten aldın. Yarın yine gel!"
	end
	local day = DailyRewardService.NextDay(data, t)
	local reward = DailyCalendar.Days[day]
	data.lastDailyClaim = t
	data.dailyStreak = day
	data.coins += reward.coins
	local text = string.format("Günlük ödül (Gün %d/%d): +%d coin", day, #DailyCalendar.Days, reward.coins)
	if reward.seed and Seeds.Get(reward.seed) then
		local c = reward.seedCount or 1
		data.inventory[reward.seed] = (data.inventory[reward.seed] or 0) + c
		text ..= string.format(" ve %dx %s", c, (Seeds.Get(reward.seed) :: any).displayName)
	end
	return true, text .. "!"
end

function DailyRewardService.Serialize(data: Types.PlayerData, now: number?)
	local list = {}
	for i, r in DailyCalendar.Days do
		local seed = r.seed and Seeds.Get(r.seed)
		list[i] = {
			coins = r.coins,
			seed = if seed then seed.displayName else nil,
			seedCount = r.seedCount,
		}
	end
	return {
		canClaim = DailyRewardService.CanClaim(data, now),
		nextDay = DailyRewardService.NextDay(data, now),
		days = list,
	}
end

return DailyRewardService
