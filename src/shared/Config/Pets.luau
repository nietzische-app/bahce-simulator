--!strict
--[[
	Evcil hayvanlar: yumurta sadece COIN ile alınır, oranlar UI'da açık, pity garanti.
	Her yumurta mutlaka faydalı bir pet verir. Takas/hediye YOK. Robux yumurta YOK.
	Modeller: ReplicatedStorage.Models/<modelName>; yoksa ModelFallback. FBX isteğe bağlıdır.
]]

export type PetBonus = {
	growth: number?, -- 1.05 = +%5 büyüme hızı
	sell: number?, -- 1.05 = +%5 satış
}

export type PetConfig = {
	id: string,
	displayName: string,
	description: string,
	rarity: string,
	bonus: PetBonus,
	modelName: string,
	placeholderColor: Color3,
	order: number,
}

export type EggOutcome = {
	petId: string,
	chance: number, -- 0..1, sum of egg outcomes = 1
}

export type EggConfig = {
	id: string,
	displayName: string,
	price: number, -- coins only
	pity: number, -- opens without pityPet => guarantee that pet
	pityPetId: string,
	outcomes: { EggOutcome },
	order: number,
}

local function pet(
	id: string,
	displayName: string,
	description: string,
	rarity: string,
	bonus: PetBonus,
	order: number,
	color: Color3
): PetConfig
	return {
		id = id,
		displayName = displayName,
		description = description,
		rarity = rarity,
		bonus = bonus,
		modelName = "Pet_" .. id,
		placeholderColor = color,
		order = order,
	}
end

local Pets = {
	MAX_EQUIPPED = 3,
	MAX_OWNED = 50,
	FOLLOW_OFFSET = Vector3.new(2.5, 0.5, 2.5),
	Pets = {
		Bunny = pet("Bunny", "Tavşan", "Büyüme +%5", "Common", { growth = 1.05 }, 1, Color3.fromRGB(240, 220, 200)),
		Chick = pet("Chick", "Civciv", "Satış +%5", "Common", { sell = 1.05 }, 2, Color3.fromRGB(255, 220, 80)),
		Frog = pet("Frog", "Kurbağa", "Büyüme +%8", "Uncommon", { growth = 1.08 }, 3, Color3.fromRGB(80, 180, 90)),
		Fox = pet("Fox", "Tilki", "Satış +%10", "Rare", { sell = 1.10 }, 4, Color3.fromRGB(230, 120, 50)),
		Owl = pet("Owl", "Baykuş", "Büyüme +%10", "Rare", { growth = 1.10 }, 5, Color3.fromRGB(140, 110, 80)),
		Hedgehog = pet("Hedgehog", "Kirpi", "Satış +%10", "Rare", { sell = 1.10 }, 6, Color3.fromRGB(160, 130, 100)),
		Dragon = pet(
			"Dragon",
			"Minik Ejder",
			"Büyüme +%5 ve satış +%5",
			"Epic",
			{ growth = 1.05, sell = 1.05 },
			7,
			Color3.fromRGB(220, 80, 100)
		),
	} :: { [string]: PetConfig },

	Eggs = {
		CommonEgg = {
			id = "CommonEgg",
			displayName = "Sade Yumurta",
			price = 150,
			pity = 25,
			pityPetId = "Fox",
			order = 1,
			outcomes = {
				{ petId = "Bunny", chance = 0.55 },
				{ petId = "Chick", chance = 0.30 },
				{ petId = "Frog", chance = 0.12 },
				{ petId = "Fox", chance = 0.03 },
			},
		},
		RareEgg = {
			id = "RareEgg",
			displayName = "Nadir Yumurta",
			price = 600,
			pity = 15,
			pityPetId = "Dragon",
			order = 2,
			outcomes = {
				{ petId = "Owl", chance = 0.50 },
				{ petId = "Hedgehog", chance = 0.35 },
				{ petId = "Dragon", chance = 0.15 },
			},
		},
	} :: { [string]: EggConfig },
}

function Pets.GetPet(id: string): PetConfig?
	return Pets.Pets[id]
end

function Pets.GetEgg(id: string): EggConfig?
	return Pets.Eggs[id]
end

function Pets.ListPets(): { PetConfig }
	local list = {}
	for _, p in Pets.Pets do
		table.insert(list, p)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function Pets.ListEggs(): { EggConfig }
	local list = {}
	for _, e in Pets.Eggs do
		table.insert(list, e)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function Pets.FormatOdds(eggId: string): string
	local egg = Pets.GetEgg(eggId)
	if not egg then
		return ""
	end
	local parts = {}
	for _, o in egg.outcomes do
		local p = Pets.GetPet(o.petId)
		table.insert(parts, string.format("%s %%%.0f", if p then p.displayName else o.petId, o.chance * 100))
	end
	local pityPet = Pets.GetPet(egg.pityPetId)
	return table.concat(parts, " | ")
		.. string.format(
			" — %s garantisi: %d yumurta",
			if pityPet then pityPet.displayName else egg.pityPetId,
			egg.pity
		)
end

function Pets.ModelNames(): { string }
	local out = {}
	for _, p in Pets.ListPets() do
		table.insert(out, p.modelName)
	end
	return out
end

return Pets
