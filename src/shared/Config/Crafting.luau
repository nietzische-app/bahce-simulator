--!strict
--[[
	Üretim (crafting): ürün (crop) + coin → alet / dekor / tohum.
	Sunucu doğrular; oran veya loot box yok.
]]

export type CraftIngredient = {
	-- "crop:<seedId>" veya düz seedId (tohum)
	key: string,
	count: number,
}

export type CraftRecipe = {
	id: string,
	displayName: string,
	description: string,
	coinCost: number,
	ingredients: { CraftIngredient },
	-- output
	kind: "gear" | "decor" | "seed",
	refId: string,
	amount: number,
	order: number,
}

local Crafting = {
	Recipes = {
		WateringCanCraft = {
			id = "WateringCanCraft",
			displayName = "Sulama Kabı Yap",
			description = "5 Güneş Çiçeği ürünü + 20 coin → 1 Sulama Kabı",
			coinCost = 20,
			ingredients = { { key = "crop:SunBloom", count = 5 } },
			kind = "gear",
			refId = "WateringCan",
			amount = 1,
			order = 1,
		},
		FertilizerCraft = {
			id = "FertilizerCraft",
			displayName = "Gübre Yap",
			description = "3 Çiy Yaprağı ürünü + 30 coin → 1 Gübre",
			coinCost = 30,
			ingredients = { { key = "crop:DewLeaf", count = 3 } },
			kind = "gear",
			refId = "Fertilizer",
			amount = 1,
			order = 2,
		},
		FenceCraft = {
			id = "FenceCraft",
			displayName = "Çit Yap",
			description = "2 Güneş Çiçeği ürünü + 10 coin → 1 Çit",
			coinCost = 10,
			ingredients = { { key = "crop:SunBloom", count = 2 } },
			kind = "decor",
			refId = "Fence",
			amount = 1,
			order = 3,
		},
		CloudBerrySeedCraft = {
			id = "CloudBerrySeedCraft",
			displayName = "Bulut Üzümü Tohumu",
			description = "4 Çiy Yaprağı ürünü + 40 coin → 1 Bulut Üzümü tohumu",
			coinCost = 40,
			ingredients = { { key = "crop:DewLeaf", count = 4 } },
			kind = "seed",
			refId = "CloudBerry",
			amount = 1,
			order = 4,
		},
		LanternCraft = {
			id = "LanternCraft",
			displayName = "Fener Yap",
			description = "2 Bulut Üzümü ürünü + 25 coin → 1 Fener",
			coinCost = 25,
			ingredients = { { key = "crop:CloudBerry", count = 2 } },
			kind = "decor",
			refId = "Lantern",
			amount = 1,
			order = 5,
		},
	} :: { [string]: CraftRecipe },
}

function Crafting.Get(id: string): CraftRecipe?
	return Crafting.Recipes[id]
end

function Crafting.ListOrdered(): { CraftRecipe }
	local list = {}
	for _, r in Crafting.Recipes do
		table.insert(list, r)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

return Crafting
