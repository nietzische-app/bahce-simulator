--!strict
--[[
	Dekorasyon dükkânı. Tamamen kozmetik — oyuna etki etmez (pay-to-win yok).
	Sadece coin ile alınır (Robux YOK). Görseller ReplicatedStorage.Models/<modelName>
	altından gelir; yoksa sunucu basit bir yer tutucu Part koyar.
]]

export type DecorConfig = {
	id: string,
	displayName: string,
	price: number,
	modelName: string,
	order: number,
	placeholderSize: Vector3,
	placeholderColor: Color3,
}

local function item(
	id: string,
	displayName: string,
	price: number,
	order: number,
	size: Vector3,
	color: Color3
): DecorConfig
	return {
		id = id,
		displayName = displayName,
		price = price,
		modelName = "Decor_" .. id,
		order = order,
		placeholderSize = size,
		placeholderColor = color,
	}
end

-- Parsel kenarında (fidan yataklarının dışında) 5x5 halkası: 16 yuva
local RING = { -10.5, -5.25, 0, 5.25, 10.5 }
local slots: { Vector3 } = {}
for _, z in RING do
	for _, x in RING do
		if math.abs(x) == 10.5 or math.abs(z) == 10.5 then
			table.insert(slots, Vector3.new(x, 0.5, z))
		end
	end
end

local Decor = {
	MAX_OWNED_PER_ITEM = 16,
	MAX_BUY_PER_REQUEST = 5,
	-- Yuva ofsetleri parsel merkezine göre; hepsi PLOT_SIZE (24x24) sınırının içinde
	SLOTS = slots,
	MAX_PLACED = #slots,
	Items = {
		Fence = item("Fence", "Çit", 25, 1, Vector3.new(4, 2, 0.4), Color3.fromRGB(170, 125, 75)),
		Bench = item("Bench", "Bank", 80, 2, Vector3.new(3.5, 1.5, 1.4), Color3.fromRGB(140, 95, 60)),
		Lantern = item("Lantern", "Fener", 60, 3, Vector3.new(0.8, 3, 0.8), Color3.fromRGB(250, 220, 120)),
		Fountain = item("Fountain", "Çeşme", 300, 4, Vector3.new(3, 2.5, 3), Color3.fromRGB(150, 190, 230)),
		FlowerPot = item(
			"FlowerPot",
			"Çiçek Saksısı",
			35,
			5,
			Vector3.new(1.4, 1.4, 1.4),
			Color3.fromRGB(220, 110, 90)
		),
		Birdhouse = item("Birdhouse", "Kuş Evi", 90, 6, Vector3.new(1.2, 3, 1.2), Color3.fromRGB(120, 170, 220)),
		Gnome = item("Gnome", "Bahçe Cücesi", 120, 7, Vector3.new(1, 1.8, 1), Color3.fromRGB(220, 60, 60)),
		Swing = item("Swing", "Salıncak", 220, 8, Vector3.new(4, 4, 2), Color3.fromRGB(200, 170, 110)),
	} :: { [string]: DecorConfig },
}

function Decor.Get(id: string): DecorConfig?
	return Decor.Items[id]
end

function Decor.ListOrdered(): { DecorConfig }
	local list = {}
	for _, d in Decor.Items do
		table.insert(list, d)
	end
	table.sort(list, function(a, b)
		return a.order < b.order
	end)
	return list
end

function Decor.ModelNames(): { string }
	local out = {}
	for _, d in Decor.ListOrdered() do
		table.insert(out, d.modelName)
	end
	return out
end

return Decor
