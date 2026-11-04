local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Events = l:require("ReplicatedStorage.Shared.Config.Events")
	local EventService = l:require("ServerScriptService.Server.Systems.EventService")
	local PetService = l:require("ServerScriptService.Server.Systems.PetService")

	local DURING = 1772323200 + 86400 -- Mar 2 2026
	local AFTER = 1773532800 + 86400 -- after Mar 15 2026

	T.describe("Events", function()
		T.it("BaharSenligi multi-day window and force toggle", function()
			local e = Events.Get("BaharSenligi")
			T.ok(e)
			T.ok(e.endUnix - e.startUnix >= 86400 * 7, "multi-day")
			T.eq(e.forceEnabled, false)
			T.ok(Events.IsActive(e, DURING))
			T.eq(Events.HasEnded(e, DURING), false)
			T.eq(Events.IsActive(e, AFTER), false)
			T.ok(Events.HasEnded(e, AFTER))
			e.forceEnabled = true
			T.ok(Events.IsActive(e, AFTER))
			T.eq(Events.HasEnded(e, AFTER), false)
			e.forceEnabled = false
		end)

		T.it("harvest grants event currency only while active", function()
			local d = F.newData()
			T.eq((d :: any).eventCurrency, nil)
			T.eq(EventService.OnHarvest(d, DURING), 1)
			T.eq((d :: any).eventCurrency.baharCicegi, 1)
			T.eq(EventService.OnHarvest(d, AFTER), 0)
			T.eq((d :: any).eventCurrency.baharCicegi, 1)
		end)

		T.it("event shop spends currency; legacy spends coins after end", function()
			local d = F.newData({ coins = 200 });
			(d :: any).eventCurrency = { baharCicegi = 20 }
			local ok, msg = EventService.BuyEvent(d, "BaharSenligi", "bahar_moon", DURING)
			T.ok(ok, msg)
			T.eq(d.inventory.MoonPetal, 1)
			T.eq((d :: any).eventCurrency.baharCicegi, 5)
			T.eq((EventService.BuyEvent(d, "BaharSenligi", "bahar_moon", AFTER)), false, "not active")

			local ok2, msg2 = EventService.BuyLegacy(d, "BaharSenligi", "bahar_gubre", AFTER)
			T.ok(ok2, msg2)
			T.eq((d.gear :: any).Fertilizer, 1)
			T.eq(d.coins, 200 - 40)
			T.eq((EventService.BuyLegacy(d, "BaharSenligi", "bahar_gubre", DURING)), false, "not ended")
		end)

		T.it("event egg grant uses PetService and keeps odds useful", function()
			local d = F.newData();
			(d :: any).eventCurrency = { baharCicegi = 30 }
			PetService.rng = F.Random.new({ 0.0 })
			local ok, msg = EventService.BuyEvent(d, "BaharSenligi", "bahar_yumurta", DURING, PetService.GrantRolledEgg)
			T.ok(ok, msg)
			T.eq(#(d :: any).pets.owned, 1)
		end)

		T.it("Serialize splits active vs legacy (Eski Etkinlikler)", function()
			local d = F.newData()
			local serAfter = EventService.Serialize(d, AFTER)
			T.eq(#serAfter.active, 0)
			T.eq(#serAfter.legacy, 1)
			T.eq(serAfter.legacy[1].id, "BaharSenligi")
			Events.Events.BaharSenligi.forceEnabled = true
			local serForce = EventService.Serialize(d, AFTER)
			T.eq(#serForce.active, 1)
			T.eq(#serForce.legacy, 0)
			Events.Events.BaharSenligi.forceEnabled = false
		end)
	end)
end
