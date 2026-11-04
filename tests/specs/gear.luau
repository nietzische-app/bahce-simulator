local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Gear = l:require("ReplicatedStorage.Shared.Config.Gear")
	local GearService = l:require("ServerScriptService.Server.Systems.GearService")
	local PlantService = l:require("ServerScriptService.Server.Systems.PlantService")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")

	local function use(d, id, slot, now)
		return GearService.Use(d, id, slot, now or os.time(), function(s)
			local _, p = PlantService.FindPlant(d, s)
			return p
		end, function(p)
			local _, ready, rem = PlantService.GetProgress(p, d)
			return ready, rem
		end)
	end

	T.describe("GearService", function()
		T.it("all gear is coin-priced and ordered", function()
			for _, g in Gear.ListOrdered() do
				T.ok(g.price > 0 and g.displayName ~= "", g.id)
			end
			T.eq(#Gear.ListOrdered(), 3)
		end)

		T.it("Buy charges coins, validates input, works on old profiles without gear", function()
			local d = F.newData({ coins = 100 })
			T.eq(d.gear, nil)
			T.ok((GearService.Buy(d, "WateringCan", 2)))
			T.eq(d.coins, 100 - 2 * Gear.Items.WateringCan.price)
			T.eq(d.gear.WateringCan, 2)
			T.eq((GearService.Buy(d, "Sprinkler", 1)), false, "not enough coins")
			T.eq((GearService.Buy(d, "Nope", 1)), false)
			T.eq((GearService.Buy(d, "WateringCan", 0 / 0)), false)
			T.eq((GearService.Buy(d, "WateringCan", 0)), false)
			T.eq((GearService.Buy(d, "WateringCan", 1000)), false)
			T.eq(d.gear.WateringCan, 2)
		end)

		T.it("WateringCan halves remaining once per plant", function()
			local d = F.newData({ inventory = { SunBloom = 1 }, gear = { WateringCan = 2 } })
			T.ok(PlantService.Plant(d, "SunBloom", 1))
			local _, _, before = PlantService.GetProgress(d.plants[1], d)
			T.ok((use(d, "WateringCan", 1)))
			local _, _, after = PlantService.GetProgress(d.plants[1], d)
			T.ok(math.abs(after - before * Gear.WATERING_REMAINING_FACTOR) <= 1)
			T.eq((use(d, "WateringCan", 1)), false, "once per plant")
			T.eq((use(d, "WateringCan", 2)), false, "empty slot")
			T.eq(d.gear.WateringCan, 1)
			local none = F.newData({ inventory = { SunBloom = 1 } })
			PlantService.Plant(none, "SunBloom", 1)
			T.eq((use(none, "WateringCan", 1)), false, "no gear owned")
		end)

		T.it("Sprinkler speeds growth in window and boosts Wet", function()
			local now = os.time()
			local d = F.newData({ gear = { Sprinkler = 2 } })
			T.ok((use(d, "Sprinkler", nil, now)))
			T.eq((use(d, "Sprinkler", nil, now)), false, "already active")
			T.eq(d.gear.Sprinkler, 1)
			T.eq(GearService.SprinklerBonus(d, now, now + 60), 60 * (Gear.SPRINKLER_GROWTH - 1))
			T.eq(GearService.SprinklerBonus(d, now, now + 10000), Gear.SPRINKLER_SECONDS * (Gear.SPRINKLER_GROWTH - 1))
			T.eq(GearService.SprinklerBonus(d, now + 10000, now + 20000), 0)
			T.eq(GearService.MutationBoosts(d, { Wet = 2 }, now).Wet, 2 * Gear.SPRINKLER_WET_BOOST)
			T.eq(GearService.MutationBoosts(d, {}, now + 99999).Wet, nil)
			T.eq(GearService.Serialize(d, now).sprinklerSecondsLeft, Gear.SPRINKLER_SECONDS)
		end)

		T.it("Fertilizer gives +1 crop on next harvest only", function()
			local seed = Seeds.Get("SunBloom")
			local d = F.newData({ inventory = { SunBloom = 2 }, gear = { Fertilizer = 1 } })
			T.ok((use(d, "Fertilizer")))
			T.eq(d.fertilizerCharges, 1)
			PlantService.Plant(d, "SunBloom", 1)
			d.plants[1].plantedAt -= seed.growTimeSeconds + 1
			PlantService.Plant(d, "SunBloom", 2)
			d.plants[2].plantedAt -= seed.growTimeSeconds + 1
			local function crops()
				local n = 0
				for k, v in d.inventory do
					if string.sub(k, 1, 5) == "crop:" then
						n += v
					end
				end
				return n
			end
			T.ok((PlantService.Harvest(d, 1)))
			T.eq(crops(), 2)
			T.ok((PlantService.Harvest(d, 2)))
			T.eq(crops(), 3)
			T.eq(d.fertilizerCharges, 0)
		end)
	end)
end
