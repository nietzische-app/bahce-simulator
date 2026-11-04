--!strict
local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local DailyRewardService = {}

local function dayIndex(now: number): number
	return math.floor(now / 86400)
end

function DailyRewardService.CanClaim(data: Types.PlayerData): boolean
	return dayIndex(os.time()) > dayIndex(data.lastDailyClaim)
end

function DailyRewardService.Claim(data: Types.PlayerData): (boolean, string)
	if not DailyRewardService.CanClaim(data) then
		return false, "Bugünkü ödülü zaten aldın. Yarın yine gel!"
	end
	data.lastDailyClaim = os.time()
	data.coins += GameConfig.DAILY_REWARD_COINS
	local seedId = GameConfig.DAILY_REWARD_SEED
	data.inventory[seedId] = (data.inventory[seedId] or 0) + GameConfig.DAILY_REWARD_SEED_COUNT
	return true,
		string.format(
			"Günlük ödül: +%d coin ve %dx %s!",
			GameConfig.DAILY_REWARD_COINS,
			GameConfig.DAILY_REWARD_SEED_COUNT,
			seedId
		)
end

return DailyRewardService
