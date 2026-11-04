local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Q = l:require("ServerScriptService.Server.Systems.QuestService")
	local Quests = l:require("ReplicatedStorage.Shared.Config.Quests")
	local Plant = l:require("ServerScriptService.Server.Systems.PlantService")
	local Econ = l:require("ServerScriptService.Server.Systems.EconomyService")
	local DAY = 86400

	T.describe("QuestService", function()
		T.it("3 distinct-kind quests per day, deterministic", function()
			for day = 0, 40 do
				local a = Q.PickForDay(day)
				T.eq(#a, Quests.PER_DAY)
				local kinds = {}
				for _, id in a do
					local k = Quests.Get(id).kind
					T.ok(not kinds[k], "duplicate kind")
					kinds[k] = true
				end
				T.eq(table.concat(a, ","), table.concat(Q.PickForDay(day), ","))
			end
		end)

		T.it("progress, claim once, and reset next UTC day without penalty", function()
			local d = F.newData({ coins = 0 })
			local now = 100 * DAY + 10
			Q.Ensure(d, now)
			local def = Quests.Get(d.quests.list[1].id)
			T.eq((Q.Claim(d, 1, now)), false)
			Q.Track(d, def.kind, def.target + 99, now)
			T.eq(d.quests.list[1].progress, def.target)
			T.ok((Q.Claim(d, 1, now)))
			T.eq(d.coins, def.rewardCoins)
			T.eq((Q.Claim(d, 1, now)), false)
			T.eq((Q.Claim(d, 99, now)), false)
			T.eq((Q.Claim(d, 0 / 0, now)), false)
			Q.Ensure(d, now + DAY)
			T.eq(d.quests.day, 101)
			T.eq(d.coins, def.rewardCoins, "no penalty")
			for _, e in d.quests.list do
				T.eq(e.progress, 0)
			end
		end)

		T.it("plant/harvest/sell hooks track progress", function()
			local d = F.newData({ coins = 0, inventory = { SunBloom = 1 } })
			d.quests = {
				day = math.floor(os.time() / DAY),
				list = {
					{ id = "plant5", progress = 0, claimed = false },
					{ id = "harvest5", progress = 0, claimed = false },
					{ id = "sell100", progress = 0, claimed = false },
				},
			}
			T.ok((Plant.Plant(d, "SunBloom", 1)))
			d.plants[1].plantedAt = 0
			T.ok((Plant.Harvest(d, 1)))
			Econ.SellAllCrops(d)
			T.eq(d.quests.list[1].progress, 1)
			T.eq(d.quests.list[2].progress, 1)
			T.ok(d.quests.list[3].progress > 0)
		end)
	end)
end
