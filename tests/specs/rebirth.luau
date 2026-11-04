local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Rebirth = l:require("ReplicatedStorage.Shared.Config.Rebirth")
	local RebirthService = l:require("ServerScriptService.Server.Systems.RebirthService")
	local Game = l:require("ReplicatedStorage.Shared.Config.Game")

	T.describe("Rebirth", function()
		T.it("multiplier stacks +0.25 per rebirth, badge names", function()
			T.eq(Rebirth.SellMultiplier(0), 1)
			T.eq(Rebirth.SellMultiplier(1), 1.25)
			T.eq(Rebirth.SellMultiplier(2), 1.50)
			T.eq(Rebirth.NextMultiplier(0), 1.25)
			T.eq(Rebirth.BadgeName(0), "")
			T.eq(Rebirth.BadgeName(1), "Bahçıvan ×1")
			T.eq(Rebirth.MIN_COINS, 500)
			T.eq(Rebirth.MIN_HARVESTED, 25)
			T.eq(Rebirth.CONFIRM_PHRASE, "YENİDEN DOĞ")
		end)

		T.it("Can rejects low coins/harvest; Perform needs exact phrase", function()
			local d = F.newData({ coins = 100, totalHarvested = 5 })
			T.eq((RebirthService.Can(d)), false)
			local d2 = F.newData({ coins = 500, totalHarvested = 25 })
			T.ok((RebirthService.Can(d2)))
			T.eq((RebirthService.Perform(d2, "yanlis")), false)
			T.eq(d2.coins, 500)
		end)

		T.it("Perform resets progress, keeps collection/decor/pets, sets multiplier", function()
			local d = F.newData({
				coins = 900,
				totalHarvested = 40,
				inventory = { SunBloom = 9, ["crop:DewLeaf"] = 3 },
				plants = { { slot = 1 } },
				upgrades = { extraSlots = 2, growthSpeedLevel = 1 },
				gear = { WateringCan = 2 },
				collection = { SunBloom = true },
				decor = { owned = { Fence = 1 }, placed = {} },
			});
			(d :: any).pets = {
				owned = { { uid = "p1", petId = "Bunny", obtainedAt = 1 } },
				equipped = { "p1" },
				pity = {},
			}
			(d :: any).eventCurrency = { baharCicegi = 9 }
			local ok, msg = RebirthService.Perform(d, "YENİDEN DOĞ")
			T.ok(ok, msg)
			T.eq((d :: any).rebirthCount, 1)
			T.eq(d.coins, Game.STARTING_COINS)
			T.eq(d.plants[1], nil)
			T.eq(d.upgrades.extraSlots, 0)
			T.eq((d.gear :: any).WateringCan, nil)
			T.eq((d :: any).eventCurrency.baharCicegi, nil)
			T.eq((d.collection :: any).SunBloom, true)
			T.eq((d.decor :: any).owned.Fence, 1)
			T.eq(#(d :: any).pets.owned, 1)
			T.eq((d :: any).pets.equipped[1], "p1")
			T.eq(RebirthService.SellMultiplier(d), 1.25)
			T.eq(d.totalHarvested, 40, "lifetime kept")
		end)

		T.it("cannot be bought — no Robux path; Serialize exposes confirm", function()
			local d = F.newData({ coins = 500, totalHarvested = 25 })
			local ser = RebirthService.Serialize(d)
			T.eq(ser.confirmPhrase, "YENİDEN DOĞ")
			T.eq(ser.nextSellMult, 1.25)
			T.ok(ser.can)
		end)
	end)
end
