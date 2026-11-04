--!strict
--[[
	PLACEHOLDER product / gamepass IDs — replace in Studio Creator Dashboard
	before publishing. See README.

	Kid-safe rules:
	- No pay-to-skip pressure timers
	- No player-to-player trading
	- No random loot boxes without disclosed odds
	- Seed Pack odds are listed below (transparent)
]]

export type GamepassDef = {
	key: string,
	displayName: string,
	description: string,
	gamePassId: number, -- PLACEHOLDER
}

export type DevProductDef = {
	key: string,
	displayName: string,
	description: string,
	productId: number, -- PLACEHOLDER
}

local Monetization = {
	Gamepasses = {
		DoubleSell = {
			key = "DoubleSell",
			displayName = "2x Satış",
			description = "Hasat satışlarından 2 kat coin kazanırsın.",
			gamePassId = 0, -- PLACEHOLDER: set real Game Pass ID
		} :: GamepassDef,
		AutoHarvest = {
			key = "AutoHarvest",
			displayName = "Otomatik Hasat",
			description = "Olgun bitkiler otomatik toplanır.",
			gamePassId = 0, -- PLACEHOLDER
		} :: GamepassDef,
		ExtraPlot = {
			key = "ExtraPlot",
			displayName = "Ekstra Parsel",
			description = "İkinci bir bahçe parseli açılır.",
			gamePassId = 0, -- PLACEHOLDER
		} :: GamepassDef,
	},

	DevProducts = {
		InstantGrow = {
			key = "InstantGrow",
			displayName = "Anında Büyüt",
			description = "Bahçendeki tüm bitkileri hemen olgunlaştırır. (Zorunlu değil — beklemek ücretsizdir.)",
			productId = 0, -- PLACEHOLDER
		} :: DevProductDef,
		SeedPack = {
			key = "SeedPack",
			displayName = "Tohum Paketi",
			description = "Rastgele tohumlar. Oranlar açıktır (aşağıda).",
			productId = 0, -- PLACEHOLDER
		} :: DevProductDef,
	},

	-- Transparent odds for Seed Pack (must sum to 1.0)
	SeedPackOdds = {
		{ seedId = "SunBloom", chance = 0.40, label = "%40 Güneş Çiçeği" },
		{ seedId = "DewLeaf", chance = 0.30, label = "%30 Çiy Yaprağı" },
		{ seedId = "CloudBerry", chance = 0.18, label = "%18 Bulut Üzümü" },
		{ seedId = "MoonPetal", chance = 0.09, label = "%9 Ay Yaprağı" },
		{ seedId = "StarRoot", chance = 0.03, label = "%3 Yıldız Kökü" },
	},

	SeedPackCount = 5,
}

function Monetization.GamepassById(id: number): GamepassDef?
	if id == 0 then
		return nil
	end
	for _, gp in pairs(Monetization.Gamepasses) do
		if gp.gamePassId == id then
			return gp
		end
	end
	return nil
end

function Monetization.ProductById(id: number): DevProductDef?
	if id == 0 then
		return nil
	end
	for _, p in pairs(Monetization.DevProducts) do
		if p.productId == id then
			return p
		end
	end
	return nil
end

function Monetization.FormatSeedPackOdds(): string
	local parts = {}
	for _, entry in Monetization.SeedPackOdds do
		table.insert(parts, entry.label)
	end
	return table.concat(parts, " · ")
end

return Monetization
