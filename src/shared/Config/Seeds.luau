--!strict
local Types = require(script.Parent.Parent.Core.Types)

export type SeedConfig = Types.SeedConfig

--[[
	Seed catalog. Colors / assetId are placeholder hooks for Studio/AI art.
	Odds for any random pack are listed in Monetization config (no hidden loot).
]]
local Seeds: { [string]: Types.SeedConfig } = {
	SunBloom = {
		id = "SunBloom",
		displayName = "Güneş Çiçeği",
		rarity = "Common",
		growTimeSeconds = 30,
		sellPrice = 8,
		buyPrice = 5,
		color = Color3.fromRGB(255, 214, 90),
		assetId = "PLACEHOLDER_SunBloom",
		modelSeedling = "SunBloom_seedling",
		modelMature = "SunBloom_mature",
	},
	DewLeaf = {
		id = "DewLeaf",
		displayName = "Çiy Yaprağı",
		rarity = "Common",
		growTimeSeconds = 45,
		sellPrice = 12,
		buyPrice = 8,
		color = Color3.fromRGB(120, 200, 140),
		assetId = "PLACEHOLDER_DewLeaf",
		modelSeedling = "DewLeaf_seedling",
		modelMature = "DewLeaf_mature",
	},
	CloudBerry = {
		id = "CloudBerry",
		displayName = "Bulut Üzümü",
		rarity = "Uncommon",
		growTimeSeconds = 90,
		sellPrice = 28,
		buyPrice = 18,
		color = Color3.fromRGB(180, 220, 255),
		assetId = "PLACEHOLDER_CloudBerry",
		modelSeedling = "CloudBerry_seedling",
		modelMature = "CloudBerry_mature",
	},
	MoonPetal = {
		id = "MoonPetal",
		displayName = "Ay Yaprağı",
		rarity = "Rare",
		growTimeSeconds = 180,
		sellPrice = 70,
		buyPrice = 45,
		color = Color3.fromRGB(200, 180, 255),
		assetId = "PLACEHOLDER_MoonPetal",
		modelSeedling = "MoonPetal_seedling",
		modelMature = "MoonPetal_mature",
	},
	StarRoot = {
		id = "StarRoot",
		displayName = "Yıldız Kökü",
		rarity = "Epic",
		growTimeSeconds = 300,
		sellPrice = 160,
		buyPrice = 100,
		color = Color3.fromRGB(255, 160, 220),
		assetId = "PLACEHOLDER_StarRoot",
		modelSeedling = "StarRoot_seedling",
		modelMature = "StarRoot_mature",
	},
}

local SeedsModule = {}

function SeedsModule.Get(id: string): Types.SeedConfig?
	return Seeds[id]
end

function SeedsModule.All(): { [string]: Types.SeedConfig }
	return Seeds
end

function SeedsModule.ListOrdered(): { Types.SeedConfig }
	local list = {}
	for _, cfg in pairs(Seeds) do
		table.insert(list, cfg)
	end
	table.sort(list, function(a, b)
		return a.buyPrice < b.buyPrice
	end)
	return list
end

return SeedsModule
