--!strict
--[[
	7-day streak calendar (escalating, all free). Missing a day gently returns
	to day 1 — nothing already earned is ever taken away.
]]

export type DayReward = { coins: number, seed: string?, seedCount: number? }

local DailyCalendar = {
	Days = {
		{ coins = 25, seed = "SunBloom", seedCount = 1 },
		{ coins = 35, seed = "DewLeaf", seedCount = 1 },
		{ coins = 50, seed = "SunBloom", seedCount = 3 },
		{ coins = 65, seed = "CloudBerry", seedCount = 1 },
		{ coins = 80, seed = "DewLeaf", seedCount = 3 },
		{ coins = 100, seed = "CloudBerry", seedCount = 2 },
		{ coins = 150, seed = "MoonPetal", seedCount = 1 },
	} :: { DayReward },
}

return DailyCalendar
