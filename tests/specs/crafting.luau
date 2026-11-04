local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Crafting = l:require("ReplicatedStorage.Shared.Config.Crafting")
	local CraftingService = l:require("ServerScriptService.Server.Systems.CraftingService")

	T.describe("Crafting", function()
		T.it("recipes exist and reference valid outputs", function()
			T.ok(#Crafting.ListOrdered() >= 4)
			for _, r in Crafting.ListOrdered() do
				T.ok(r.coinCost >= 0, r.id)
				T.ok(#r.ingredients > 0, r.id)
			end
		end)

		T.it("Craft consumes crops+coins and grants gear", function()
			local d = F.newData({
				coins = 50,
				inventory = { ["crop:SunBloom"] = 5 },
			})
			local ok, msg = CraftingService.Craft(d, "WateringCanCraft")
			T.ok(ok, msg)
			T.eq(d.coins, 30)
			T.eq(d.inventory["crop:SunBloom"], nil)
			T.eq((d.gear :: any).WateringCan, 1)
		end)

		T.it("Craft grants decor and seed recipes; rejects missing mats", function()
			local d = F.newData({ coins = 100, inventory = { ["crop:SunBloom"] = 2 } })
			T.ok((CraftingService.Craft(d, "FenceCraft")))
			T.eq((d.decor :: any).owned.Fence, 1)

			local d2 = F.newData({ coins = 100, inventory = { ["crop:DewLeaf"] = 4 } })
			T.ok((CraftingService.Craft(d2, "CloudBerrySeedCraft")))
			T.eq(d2.inventory.CloudBerry, 1)

			local poor = F.newData({ coins = 5, inventory = { ["crop:SunBloom"] = 5 } })
			T.eq((CraftingService.Craft(poor, "WateringCanCraft")), false)
			T.eq((CraftingService.Craft(d, "Nope")), false)
		end)
	end)
end
