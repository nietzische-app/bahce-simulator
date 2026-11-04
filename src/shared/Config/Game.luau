--!strict
--[[
	Global game constants for Minik Bahçe.
]]

local Game = {
	DISPLAY_NAME = "Minik Bahçe",
	DATA_STORE_NAME = "MinikBahce_PlayerData_v1",
	LEADERBOARD_STORE = "MinikBahce_Coins_v1",
	DATA_VERSION = 1,

	STARTING_COINS = 50,
	STARTING_SEEDS = {
		SunBloom = 3,
		DewLeaf = 2,
	},

	BASE_PLOT_SLOTS = 4,
	MAX_EXTRA_SLOTS = 4,
	PLOT_COUNT = 8,
	PLOT_SIZE = Vector3.new(24, 1, 24),
	PLOT_SPACING = 32,

	-- Growth upgrade: each level shaves 10% off grow time (min 40% of base)
	GROWTH_SPEED_PER_LEVEL = 0.10,
	GROWTH_SPEED_MAX_LEVEL = 5,
	GROWTH_SPEED_UPGRADE_BASE_COST = 100,

	SLOT_UPGRADE_BASE_COST = 150,

	DAILY_REWARD_COINS = 25,
	DAILY_REWARD_SEED = "SunBloom",
	DAILY_REWARD_SEED_COUNT = 1,

	SESSION_LOCK_SECONDS = 60 * 30,
	SAVE_INTERVAL_SECONDS = 60,
	LEADERBOARD_UPDATE_SECONDS = 30,

	AUTO_HARVEST_INTERVAL = 5,
}

return Game
