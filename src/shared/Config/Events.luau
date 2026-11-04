--!strict
--[[
	Mevsimsel etkinlik çerçevesi (config-driven).
	- start/end tarihler (çok günlük)
	- etkinlik para birimi hasattan kazanılır
	- etkinlik dükkânı
	- bittikten sonra ödüller "Eski Etkinlikler" dükkânında coin ile alınabilir (FOMO yok)
	forceEnabled=true test için tarihi yok sayar.
]]

export type EventShopItem = {
	id: string,
	displayName: string,
	description: string,
	-- Event currency cost while active
	eventCost: number,
	-- Coin cost in "Eski Etkinlikler" after event ends (always obtainable later)
	legacyCoinCost: number,
	kind: "seed" | "gear" | "decor" | "egg",
	refId: string, -- seedId / gearId / decorId / eggId
	amount: number,
	order: number,
}

export type EventConfig = {
	id: string,
	displayName: string,
	description: string,
	currencyId: string,
	currencyName: string,
	startUnix: number, -- inclusive
	endUnix: number, -- exclusive
	forceEnabled: boolean, -- toggle; true => active regardless of date
	harvestCurrency: number, -- granted per successful harvest while active
	shop: { EventShopItem },
}

-- Bahar Şenliği: 1–14 Mart 2026 (UTC). Bugün (Kasım 2026) itibarıyla bitmiş → Eski Etkinlikler.
-- Test için forceEnabled = true yapılabilir.
local MARCH_1_2026 = 1772323200 -- 2026-03-01 00:00:00 UTC
local MARCH_15_2026 = 1773532800 -- 2026-03-15 00:00:00 UTC

local Events = {
	Events = {
		BaharSenligi = {
			id = "BaharSenligi",
			displayName = "Bahar Şenliği",
			description = "Hasat ederek Bahar Çiçeği topla; şenlik dükkânından ödül al. Bittikten sonra aynı ödüller Eski Etkinlikler'de coin ile kalır.",
			currencyId = "baharCicegi",
			currencyName = "Bahar Çiçeği",
			startUnix = MARCH_1_2026,
			endUnix = MARCH_15_2026,
			forceEnabled = false,
			harvestCurrency = 1,
			shop = {
				{
					id = "bahar_moon",
					displayName = "Ay Yaprağı Tohumu",
					description = "Etkinlik hediyesi: 1 Ay Yaprağı tohumu",
					eventCost = 15,
					legacyCoinCost = 60,
					kind = "seed",
					refId = "MoonPetal",
					amount = 1,
					order = 1,
				},
				{
					id = "bahar_gubre",
					displayName = "Şenlik Gübre",
					description = "1 Gübre",
					eventCost = 8,
					legacyCoinCost = 40,
					kind = "gear",
					refId = "Fertilizer",
					amount = 1,
					order = 2,
				},
				{
					id = "bahar_saksi",
					displayName = "Bahar Saksısı",
					description = "1 Çiçek Saksısı (dekor)",
					eventCost = 12,
					legacyCoinCost = 50,
					kind = "decor",
					refId = "FlowerPot",
					amount = 1,
					order = 3,
				},
				{
					id = "bahar_yumurta",
					displayName = "Bahar Yumurtası",
					description = "1 Sade Yumurta (pet)",
					eventCost = 25,
					legacyCoinCost = 180,
					kind = "egg",
					refId = "CommonEgg",
					amount = 1,
					order = 4,
				},
			},
		},
	} :: { [string]: EventConfig },
}

function Events.Get(id: string): EventConfig?
	return Events.Events[id]
end

function Events.All(): { EventConfig }
	local list = {}
	for _, e in Events.Events do
		table.insert(list, e)
	end
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	return list
end

function Events.IsActive(cfg: EventConfig, now: number): boolean
	if cfg.forceEnabled then
		return true
	end
	return now >= cfg.startUnix and now < cfg.endUnix
end

function Events.HasEnded(cfg: EventConfig, now: number): boolean
	if cfg.forceEnabled then
		return false
	end
	return now >= cfg.endUnix
end

return Events
