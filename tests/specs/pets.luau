local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Pets = l:require("ReplicatedStorage.Shared.Config.Pets")
	local PetService = l:require("ServerScriptService.Server.Systems.PetService")

	T.describe("Pets", function()
		T.it("eggs are coin-priced, odds sum to 1, pity set", function()
			for _, e in Pets.ListEggs() do
				T.ok(e.price > 0, e.id)
				local sum = 0
				for _, o in e.outcomes do
					sum += o.chance
					T.ok(Pets.GetPet(o.petId), o.petId)
				end
				T.ok(math.abs(sum - 1) < 1e-6, e.id .. " odds")
				T.ok(e.pity >= 5 and Pets.GetPet(e.pityPetId), e.id .. " pity")
				T.ok(#Pets.FormatOdds(e.id) > 10, "odds string")
			end
			T.eq(#Pets.ListEggs(), 2)
			T.eq(Pets.Eggs.CommonEgg.price, 150)
			T.eq(Pets.Eggs.RareEgg.price, 600)
			T.eq(Pets.Eggs.CommonEgg.pity, 25)
			T.eq(Pets.Eggs.RareEgg.pity, 15)
		end)

		T.it("every pet has a useful bonus and modelName", function()
			for _, p in Pets.ListPets() do
				T.ok((p.bonus.growth or 0) > 1 or (p.bonus.sell or 0) > 1, p.id)
				T.eq(p.modelName, "Pet_" .. p.id)
			end
		end)

		T.it("BuyEgg charges coins, works on old profiles, validates", function()
			local d = F.newData({ coins = 150 })
			T.eq((d :: any).pets, nil)
			PetService.rng = F.Random.new({ 0.0 }) -- first outcome Bunny
			local ok, msg, petId = PetService.BuyEgg(d, "CommonEgg")
			T.ok(ok, msg)
			T.eq(petId, "Bunny")
			T.eq(d.coins, 0)
			T.eq(#(d :: any).pets.owned, 1)
			T.eq((PetService.BuyEgg(d, "CommonEgg")), false, "no coins")
			T.eq((PetService.BuyEgg(d, "Nope")), false)
			local rich = F.newData({ coins = 10000 })
			PetService.rng = F.Random.new({ 0.99 }) -- Fox band
			T.ok((PetService.BuyEgg(rich, "CommonEgg")))
		end)

		T.it("pity guarantees Fox after 25 CommonEgg opens without Fox", function()
			local d = F.newData({ coins = 150 * 30 })
			-- Always roll into Bunny band (0.0)
			PetService.rng = F.Random.new({})
			for i = 1, 24 do
				PetService.rng.seq = { 0.0 }
				PetService.rng.i = 0
				local ok, _, id = PetService.BuyEgg(d, "CommonEgg")
				T.ok(ok)
				T.eq(id, "Bunny", "open " .. i)
			end
			PetService.rng.seq = { 0.0 }
			PetService.rng.i = 0
			local ok, _, id = PetService.BuyEgg(d, "CommonEgg")
			T.ok(ok)
			T.eq(id, "Fox", "pity")
		end)

		T.it("equip up to 3, bonuses stack, unequip", function()
			local d = F.newData({ coins = 150 * 5 })
			PetService.rng = F.Random.new({ 0.0 })
			for _ = 1, 4 do
				PetService.rng.i = 0
				PetService.rng.seq = { 0.0 }
				T.ok((PetService.BuyEgg(d, "CommonEgg")))
			end
			local p = (d :: any).pets
			T.ok((PetService.Equip(d, p.owned[1].uid)))
			T.ok((PetService.Equip(d, p.owned[2].uid)))
			T.ok((PetService.Equip(d, p.owned[3].uid)))
			T.eq((PetService.Equip(d, p.owned[4].uid)), false, "max 3")
			T.ok(PetService.GrowthMultiplier(d) > 1)
			T.ok((PetService.Unequip(d, p.owned[1].uid)))
			T.eq(#p.equipped, 2)
			local ser = PetService.Serialize(d)
			T.eq(ser.maxEquipped, 3)
			T.ok(#ser.eggs == 2)
		end)
	end)
end
