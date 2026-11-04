--!strict
--[[
	Bahçe aletleri (Gear). Sadece coin ile alınır — Robux YOK.
	Her zaman rafta (garanti stok, FOMO yok).
]]

export type GearConfig = {
	id: string,
	displayName: string,
	description: string,
	price: number,
	order: number,
}

local Gear = {
	MAX_OWNED = 99,
	MAX_BUY_PER_REQUEST = 10,
	-- Sulama Kabı: tek bitkinin kalan süresini yarıya indirir (bitki başına 1 kez)
	WATERING_REMAINING_FACTOR = 0.5,
	-- Sprinkler: parseldeki tüm bitkiler süre boyunca 1.5x hızlı büyür, Islak şansı 1.5x
	SPRINKLER_SECONDS = 3 * 60,
	SPRINKLER_GROWTH = 1.5,
	SPRINKLER_WET_BOOST = 1.5,
	-- Gübre: sonraki hasatta +1 ürün
	FERTILIZER_BONUS_CROPS = 1,
	MAX_FERTILIZER_CHARGES = 5,
	Items = {
		WateringCan = {
			id = "WateringCan",
			displayName = "Sulama Kabı",
			description = "Bir bitkinin kalan büyüme süresini yarıya indirir.",
			price = 40,
			order = 1,
		},
		Sprinkler = {
			id = "Sprinkler",
			displayName = "Sprinkler",
			description = "3 dk boyunca parseldeki bitkiler 1.5x hızlı büyür, Islak şansı artar.",
			price = 150,
			order = 2,
		},
		Fertilizer = {
			id = "Fertilizer",
			displayName = "Gübre",
			description = "Sonraki hasatta +1 ürün verir.",
			price = 60,
			order = 3,
		},
	} :: { [string]: GearConfig },
}

function Gear.Get(id: string): GearConfig?
	return Gear.Items[id]
end

function Gear.ListOrdered(): { GearConfig }
	local list = {}
	for _, g in Gear.Items do
		table.insert(list, g)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

return Gear
