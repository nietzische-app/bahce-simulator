local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l, weather = F.serverLoader()
	local M = l:require("ReplicatedStorage.Shared.Config.Mutations")
	local W = l:require("ReplicatedStorage.Shared.Config.Weather")
	local Econ = l:require("ServerScriptService.Server.Systems.EconomyService")
	local Plant = l:require("ServerScriptService.Server.Systems.PlantService")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")

	T.describe("Mutations", function()
		T.it("Roll picks by cumulative base odds (rarest first)", function()
			T.eq((M.Roll(F.Random.new({ 0.0005 }))), "Rainbow")
			T.eq((M.Roll(F.Random.new({ 0.003 }))), "Golden")
			T.eq((M.Roll(F.Random.new({ 0.01 }))), "Frozen")
			T.eq((M.Roll(F.Random.new({ 0.05 }))), "Wet")
			T.eq((M.Roll(F.Random.new({ 0.5 }))), nil)
		end)

		T.it("Golden pity forces Golden and resets", function()
			local id, p = M.Roll(F.Random.new({ 0.99 }), nil, M.GOLDEN_PITY - 1)
			T.eq(id, "Golden")
			T.eq(p, 0)
			local id2, p2 = M.Roll(F.Random.new({ 0.99 }), nil, 5)
			T.eq(id2, nil)
			T.eq(p2, 6)
		end)

		T.it("crop keys parse and stay backward compatible", function()
			T.eq(M.CropKey("SunBloom"), "crop:SunBloom")
			local s, m = M.ParseCropKey("crop:SunBloom:Golden")
			T.eq(s, "SunBloom")
			T.eq(m, "Golden")
			local s2, m2 = M.ParseCropKey("crop:SunBloom")
			T.eq(s2, "SunBloom")
			T.eq(m2, nil)
			T.eq((M.ParseCropKey("SunBloom")), nil)
		end)

		T.it("weather boost raises chance and is capped", function()
			local rain = W.GetShort("Rain")
			local c = M.EffectiveChances(rain.mutationBoosts)
			T.near(c.Wet, M.Get("Wet").chance * 5, 1e-9)
			T.near(c.Golden, M.Get("Golden").chance, 1e-9)
			-- 0.2 is a normal crop without rain, Wet with rain
			T.eq((M.Roll(F.Random.new({ 0.2 }))), nil)
			T.eq((M.Roll(F.Random.new({ 0.2 }), rain.mutationBoosts)), "Wet")
			local huge = M.EffectiveChances({ Wet = 1000 })
			local total = 0
			for _, v in huge do
				total += v
			end
			T.ok(total <= M.MAX_TOTAL_CHANCE + 1e-9)
		end)

		T.it("short events pick by weight with valid durations", function()
			for _, r in { 0.0, 0.6, 0.95 } do
				local ev, dur = W.PickShortEvent(F.Random.new({ r, 0.5 }))
				T.ok(dur >= ev.minDuration and dur <= ev.maxDuration)
			end
			T.eq((W.PickShortEvent(F.Random.new({ 0.0 }))).id, "Rain")
			local gap = W.NextGap(F.Random.new({ 0.5 }))
			T.ok(gap >= 15 * 60 and gap <= 25 * 60)
		end)

		T.it("SellAllCrops applies mutation multiplier", function()
			local d = F.newData({ inventory = { ["crop:SunBloom:Golden"] = 1, ["crop:SunBloom"] = 1 } })
			local ok, _, total = Econ.SellAllCrops(d)
			T.ok(ok)
			T.eq(total, Seeds.Get("SunBloom").sellPrice * 21)
			T.eq(d.inventory["crop:SunBloom:Golden"], nil)
		end)

		T.it("Harvest stores mutated crop using weather boosts", function()
			weather.boosts = { Wet = 5 }
			Plant.rng = F.Random.new({ 0.2 })
			local d = F.newData({ plants = { { seedId = "SunBloom", plantedAt = 0, slotIndex = 1 } } })
			T.ok((Plant.Harvest(d, 1)))
			T.eq(d.inventory["crop:SunBloom:Wet"], 1)
			T.eq(d.goldenPity, 1)
			weather.boosts = nil
		end)
	end)
end
