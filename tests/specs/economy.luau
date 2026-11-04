local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l, weather = F.serverLoader()
	local Econ = l:require("ServerScriptService.Server.Systems.EconomyService")
	local Game = l:require("ReplicatedStorage.Shared.Config.Game")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")
	local Mon = l:require("ReplicatedStorage.Shared.Config.Monetization")

	T.describe("EconomyService", function()
		T.it("BuySeed deducts coins and adds seeds", function()
			local d = F.newData({ coins = 100 })
			T.ok((Econ.BuySeed(d, "SunBloom", 3)))
			T.eq(d.coins, 100 - Seeds.Get("SunBloom").buyPrice * 3)
			T.eq(d.inventory.SunBloom, 3)
		end)

		T.it("BuySeed rejects bad amount / seed / insufficient coins", function()
			local d = F.newData({ coins = 10 })
			T.eq((Econ.BuySeed(d, "SunBloom", 0)), false)
			T.eq((Econ.BuySeed(d, "SunBloom", 51)), false)
			T.eq((Econ.BuySeed(d, "Nope", 1)), false)
			T.eq((Econ.BuySeed(d, "StarRoot", 1)), false)
			T.eq(d.coins, 10)
		end)

		T.it("BuySeed rejects NaN amount (would corrupt coins)", function()
			local d = F.newData({ coins = 10 })
			T.eq((Econ.BuySeed(d, "SunBloom", 0 / 0)), false)
			T.eq(d.coins, 10)
			T.eq(d.inventory.SunBloom, nil)
		end)

		T.it("SellAllCrops sums crops with multipliers and clears them", function()
			weather.sell = 1.2
			local d = F.newData({ inventory = { ["crop:SunBloom"] = 2, ["crop:DewLeaf"] = 1, SunBloom = 4 } })
			local ok, _, total = Econ.SellAllCrops(d)
			T.ok(ok)
			local expect = math.floor(Seeds.Get("SunBloom").sellPrice * 2 * 1.2)
				+ math.floor(Seeds.Get("DewLeaf").sellPrice * 1 * 1.2)
			T.eq(total, expect)
			T.eq(d.coins, expect)
			T.eq(d.totalEarned, expect)
			T.eq(d.inventory["crop:SunBloom"], nil)
			T.eq(d.inventory.SunBloom, 4, "seeds untouched")
			weather.sell = 1
		end)

		T.it("SellAllCrops doubles with DoubleSell gamepass; fails when empty", function()
			local d = F.newData({ inventory = { ["crop:StarRoot"] = 1 }, ownedGamepasses = { DoubleSell = true } })
			local _, _, total = Econ.SellAllCrops(d)
			T.eq(total, Seeds.Get("StarRoot").sellPrice * 2)
			T.eq((Econ.SellAllCrops(d)), false)
		end)

		T.it("upgrade costs scale and cap", function()
			local d = F.newData({ coins = 1e9 })
			for i = 1, Game.MAX_EXTRA_SLOTS do
				T.eq(Econ.SlotUpgradeCost(d), Game.SLOT_UPGRADE_BASE_COST * i)
				T.ok((Econ.BuyUpgrade(d, "slots")))
			end
			T.eq(Econ.SlotUpgradeCost(d), nil)
			T.eq((Econ.BuyUpgrade(d, "slots")), false)
			for i = 1, Game.GROWTH_SPEED_MAX_LEVEL do
				T.eq(Econ.GrowthUpgradeCost(d), Game.GROWTH_SPEED_UPGRADE_BASE_COST * i)
				T.ok((Econ.BuyUpgrade(d, "growth")))
			end
			T.eq(Econ.GrowthUpgradeCost(d), nil)
			T.eq((Econ.BuyUpgrade(d, "bogus")), false)
		end)

		T.it("BuyUpgrade fails without coins", function()
			local d = F.newData({ coins = 0 })
			T.eq((Econ.BuyUpgrade(d, "slots")), false)
			T.eq(d.upgrades.extraSlots, 0)
		end)

		T.it("SeedPack odds sum to 1.0 and reference real seeds", function()
			local sum = 0
			for _, e in Mon.SeedPackOdds do
				sum += e.chance
				T.ok(Seeds.Get(e.seedId), "unknown seed in odds: " .. e.seedId)
			end
			T.near(sum, 1.0, 1e-9)
		end)

		T.it("GrantSeedPack picks by cumulative odds", function()
			local d = F.newData()
			local rng = F.Random.new({ 0.0, 0.39, 0.5, 0.95, 0.999 })
			Econ.GrantSeedPack(d, rng)
			T.eq(d.inventory.SunBloom, 2)
			T.eq(d.inventory.DewLeaf, 1)
			T.eq(d.inventory.MoonPetal, 1)
			T.eq(d.inventory.StarRoot, 1)
		end)
	end)
end
