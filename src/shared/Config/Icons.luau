--!strict
--[[
	2D UI ikonları. PNG dosyaları assets/icons/ altında.
	Roblox Open Cloud 403 verdiği için rbxassetid'leri Studio Asset Manager
	ile yükleyip buraya yapıştırmanız gerekir (docs/STUDIO_ICON_IMPORT_TR.md).

	Boş string = henüz yüklenmedi → UI renk swatch / metin gösterir.
]]

local Icons = {
	-- key → numeric asset id only (no rbxassetid:// prefix). Paste after upload.
	Seed_SunBloom = "",
	Seed_DewLeaf = "",
	Seed_CloudBerry = "",
	Seed_MoonPetal = "",
	Seed_StarRoot = "",
	World_GardenPlot = "",
	World_SeedShop = "",
	World_SellStand = "",
	Pet_Bunny = "",
	Pet_Chick = "",
	Pet_Frog = "",
	Pet_Fox = "",
	Pet_Owl = "",
	Pet_Hedgehog = "",
}

-- PNG file stem → config key (for docs / mapping paste file)
Icons.Files = {
	{ key = "Seed_SunBloom", file = "Seed_SunBloom.png", usedBy = "Seeds.SunBloom.assetId" },
	{ key = "Seed_DewLeaf", file = "Seed_DewLeaf.png", usedBy = "Seeds.DewLeaf.assetId" },
	{ key = "Seed_CloudBerry", file = "Seed_CloudBerry.png", usedBy = "Seeds.CloudBerry.assetId" },
	{ key = "Seed_MoonPetal", file = "Seed_MoonPetal.png", usedBy = "Seeds.MoonPetal.assetId" },
	{ key = "Seed_StarRoot", file = "Seed_StarRoot.png", usedBy = "Seeds.StarRoot.assetId" },
	{ key = "World_GardenPlot", file = "World_GardenPlot.png", usedBy = "UI" },
	{ key = "World_SeedShop", file = "World_SeedShop.png", usedBy = "UI" },
	{ key = "World_SellStand", file = "World_SellStand.png", usedBy = "UI" },
	{ key = "Pet_Bunny", file = "Pet_Bunny.png", usedBy = "Pets UI" },
	{ key = "Pet_Chick", file = "Pet_Chick.png", usedBy = "Pets UI" },
	{ key = "Pet_Frog", file = "Pet_Frog.png", usedBy = "Pets UI" },
	{ key = "Pet_Fox", file = "Pet_Fox.png", usedBy = "Pets UI" },
	{ key = "Pet_Owl", file = "Pet_Owl.png", usedBy = "Pets UI" },
	{ key = "Pet_Hedgehog", file = "Pet_Hedgehog.png", usedBy = "Pets UI" },
}

function Icons.Rbx(key: string): string?
	local id = (Icons :: any)[key]
	if typeof(id) == "string" and id ~= "" then
		if string.sub(id, 1, 13) == "rbxassetid://" then
			return id
		end
		return "rbxassetid://" .. id
	end
	return nil
end

function Icons.ForSeed(seedId: string): string?
	return Icons.Rbx("Seed_" .. seedId)
end

return Icons
