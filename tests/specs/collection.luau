local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local CS = l:require("ServerScriptService.Server.Systems.CollectionService")
	local Collection = l:require("ReplicatedStorage.Shared.Config.Collection")
	local OfflineService = l:require("ServerScriptService.Server.Systems.OfflineService")
	local PlantService = l:require("ServerScriptService.Server.Systems.PlantService")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")

	T.describe("Collection", function()
		T.it("backfills old profiles from inventory crops", function()
			local d = F.newData({ inventory = { ["crop:SunBloom"] = 2, ["crop:DewLeaf:Wet"] = 1, ["crop:Bad"] = 1 } })
			CS.Ensure(d)
			T.eq(d.collection["crop:SunBloom"], 0)
			T.eq(d.collection["crop:DewLeaf:Wet"], 0)
			T.eq(d.collection["crop:Bad"], nil)
			local have, total = CS.RowProgress(d, "SunBloom")
			T.eq(have, 1)
			T.eq(total, #Collection.Variants())
		end)

		T.it("harvest unlocks entry once", function()
			local seed = Seeds.Get("SunBloom")
			local d = F.newData({ inventory = { SunBloom = 2 } })
			PlantService.Plant(d, "SunBloom", 1)
			d.plants[1].plantedAt -= seed.growTimeSeconds + 1
			local ok = PlantService.Harvest(d, 1)
			T.ok(ok)
			local have = CS.RowProgress(d, "SunBloom")
			T.eq(have, 1)
			T.eq(CS.Record(d, "SunBloom", nil, 1), false)
			T.eq(CS.Record(d, "Nope", nil, 1), false)
		end)

		T.it("row reward only when complete and only once", function()
			local d = F.newData({ coins = 0 })
			T.eq((CS.ClaimRow(d, "SunBloom")), false)
			for _, v in Collection.Variants() do
				CS.Record(d, "SunBloom", if v == "Normal" then nil else v, 1)
			end
			T.ok((CS.ClaimRow(d, "SunBloom")))
			T.eq(d.coins, Collection.RowReward("SunBloom"))
			T.eq((CS.ClaimRow(d, "SunBloom")), false)
			T.eq((CS.ClaimRow(d, "Nope")), false)
			local s = CS.Serialize(d)
			T.eq(s.rows[1].percent, 100)
			T.ok(s.rows[1].claimed)
		end)
	end)

	T.describe("OfflineSummary", function()
		T.it("lists plants ripened while away", function()
			local seed = Seeds.Get("SunBloom")
			local now = os.time()
			local d = F.newData({ inventory = { SunBloom = 2 } })
			PlantService.Plant(d, "SunBloom", 1)
			PlantService.Plant(d, "SunBloom", 2)
			d.plants[1].plantedAt = now - 3600 -- ripe before leaving
			d.plants[2].plantedAt = now - 120 - seed.growTimeSeconds + 60 -- ripened while away
			d.lastSeenAt = now - 120
			local s = OfflineService.Build(d, now, function(p, t)
				return PlantService.IsReadyAt(p, d, t)
			end)
			T.ok(s)
			T.eq(#s.ripened, 1)
			T.eq(s.ripened[1].count, 1)
			T.eq(s.awaySeconds, 120)
			T.eq(
				OfflineService.Build(F.newData({}), now, function()
					return true
				end),
				nil,
				"first join"
			)
			d.lastSeenAt = now - 5
			T.eq(
				OfflineService.Build(d, now, function()
					return true
				end),
				nil,
				"short absence"
			)
			T.eq(OfflineService.FormatDuration(90061), "1 gün 1 saat")
		end)
	end)
end
