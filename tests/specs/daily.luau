local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Daily = l:require("ServerScriptService.Server.Systems.DailyRewardService")
	local Cal = l:require("ReplicatedStorage.Shared.Config.DailyCalendar")
	local DAY = 86400
	local base = 20000 * DAY + 3600

	T.describe("DailyRewardService (7-day streak)", function()
		T.it("first claim = day 1; second same-day claim fails", function()
			local d = F.newData()
			T.ok(Daily.CanClaim(d, base))
			T.ok((Daily.Claim(d, base)))
			T.eq(d.coins, Cal.Days[1].coins)
			T.eq(d.inventory[Cal.Days[1].seed], Cal.Days[1].seedCount)
			T.ok(not Daily.CanClaim(d, base + 100))
			T.eq((Daily.Claim(d, base + 100)), false)
			T.eq(d.coins, Cal.Days[1].coins)
		end)

		T.it("consecutive days escalate and wrap after day 7", function()
			local d = F.newData()
			local total = 0
			for i = 1, 8 do
				T.ok((Daily.Claim(d, base + (i - 1) * DAY)))
				local expectDay = (i - 1) % 7 + 1
				T.eq(d.dailyStreak, expectDay)
				total += Cal.Days[expectDay].coins
			end
			T.eq(d.coins, total)
			for i = 2, 7 do
				T.ok(Cal.Days[i].coins > Cal.Days[i - 1].coins, "escalating")
			end
		end)

		T.it("missing a day gently restarts at day 1 without loss", function()
			local d = F.newData()
			Daily.Claim(d, base)
			Daily.Claim(d, base + DAY)
			local coins = d.coins
			T.ok((Daily.Claim(d, base + 4 * DAY)))
			T.eq(d.dailyStreak, 1)
			T.eq(d.coins, coins + Cal.Days[1].coins)
		end)

		T.it("old saves (lastDailyClaim only, no streak) stay compatible", function()
			local d = F.newData({ lastDailyClaim = base - DAY })
			T.eq(d.dailyStreak, nil)
			T.ok(Daily.CanClaim(d, base))
			T.ok((Daily.Claim(d, base)))
			T.eq(d.dailyStreak, 1)
			local s = Daily.Serialize(d, base)
			T.eq(#s.days, 7)
			T.eq(s.canClaim, false)
			T.eq(s.nextDay, 2)
		end)
	end)
end
