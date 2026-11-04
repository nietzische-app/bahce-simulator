--!strict
--[[
	Hub / çevre dekor yerleşimi. Modeller ReplicatedStorage.Models/<name>
	altından runtime clone edilir; yoksa PlotService yer tutucu Part koyar.
	Yarınlık 9 model (Pet_* çoğu, Fountain/Birdhouse/Swing) burada yok.
]]

export type PropSpec = {
	name: string,
	x: number,
	y: number,
	z: number,
	yawDegrees: number?,
}

local WorldLayout = {
	-- Merkez hub: dükkân + satış + örnek toprak yatağı
	Hub = {
		{ name = "SeedShopStall", x = -28, y = 0, z = 0, yawDegrees = 90 },
		{ name = "SellStand", x = 28, y = 0, z = 0, yawDegrees = -90 },
		{ name = "GardenPlot", x = 0, y = 0, z = 28, yawDegrees = 0 },
		{ name = "Decor_Bench", x = -8, y = 0, z = 22, yawDegrees = 15 },
		{ name = "Decor_Lantern", x = 8, y = 0, z = 22, yawDegrees = 0 },
		{ name = "Decor_Gnome", x = 4, y = 0, z = 26, yawDegrees = -30 },
		{ name = "Decor_FlowerPot", x = -4, y = 0, z = 26, yawDegrees = 0 },
		{ name = "Sprinkler", x = 0, y = 0, z = 18, yawDegrees = 0 },
	} :: { PropSpec },

	-- Çevre: ağaç / kaya / çiçek / kütük (Poly Haven CC0 world props)
	Scenery = {
		-- Kuzey ağaç hattı
		{ name = "WorldTree", x = -40, y = 0, z = -30, yawDegrees = 20 },
		{ name = "WorldTree", x = -20, y = 0, z = -36, yawDegrees = 80 },
		{ name = "WorldTree", x = 10, y = 0, z = -34, yawDegrees = 140 },
		{ name = "WorldTree", x = 35, y = 0, z = -28, yawDegrees = 200 },
		{ name = "WorldTree", x = 50, y = 0, z = -10, yawDegrees = 260 },
		{ name = "WorldTree", x = -50, y = 0, z = 10, yawDegrees = 40 },
		{ name = "WorldTree", x = -48, y = 0, z = 30, yawDegrees = 100 },
		{ name = "WorldTree", x = 48, y = 0, z = 32, yawDegrees = 310 },
		-- Kayalar
		{ name = "WorldRock", x = -35, y = 0, z = 18, yawDegrees = 45 },
		{ name = "WorldRock", x = 38, y = 0, z = -18, yawDegrees = 120 },
		{ name = "WorldRocks", x = -15, y = 0, z = 40, yawDegrees = 0 },
		{ name = "WorldRocks", x = 20, y = 0, z = 42, yawDegrees = 70 },
		{ name = "WorldLog", x = 12, y = 0, z = -22, yawDegrees = 25 },
		{ name = "WorldLog", x = -30, y = 0, z = -12, yawDegrees = 95 },
		-- Çiçek / eğrelti kümeleri (hub çevresi)
		{ name = "WorldFlowerA", x = -6, y = 0, z = 14, yawDegrees = 0 },
		{ name = "WorldFlowerB", x = 6, y = 0, z = 14, yawDegrees = 40 },
		{ name = "WorldFlowerC", x = -10, y = 0, z = 18, yawDegrees = 80 },
		{ name = "WorldFlowerA", x = 10, y = 0, z = 18, yawDegrees = 120 },
		{ name = "WorldFern", x = -22, y = 0, z = 12, yawDegrees = 0 },
		{ name = "WorldFern", x = 22, y = 0, z = 12, yawDegrees = 60 },
		{ name = "WorldFlowerB", x = -18, y = 0, z = -8, yawDegrees = 20 },
		{ name = "WorldFlowerC", x = 18, y = 0, z = -8, yawDegrees = 50 },
		{ name = "WorldFlowerA", x = 0, y = 0, z = -16, yawDegrees = 10 },
		{ name = "WorldFern", x = -42, y = 0, z = -8, yawDegrees = 30 },
		{ name = "WorldFlowerB", x = 42, y = 0, z = 8, yawDegrees = 90 },
		-- Parsel sırası kenarı (PLOT_SPACING=32, 8 parsel)
		{ name = "WorldTree", x = -112, y = 0, z = -18, yawDegrees = 0 },
		{ name = "WorldTree", x = 112, y = 0, z = -18, yawDegrees = 180 },
		{ name = "WorldRock", x = -96, y = 0, z = 16, yawDegrees = 15 },
		{ name = "WorldRock", x = 96, y = 0, z = 16, yawDegrees = 200 },
		{ name = "WorldFlowerC", x = -64, y = 0, z = 14, yawDegrees = 0 },
		{ name = "WorldFlowerA", x = 64, y = 0, z = 14, yawDegrees = 45 },
		{ name = "Decor_Fence", x = -28, y = 0, z = -14, yawDegrees = 0 },
		{ name = "Decor_Fence", x = 28, y = 0, z = -14, yawDegrees = 0 },
	} :: { PropSpec },

	-- Toprak yolu: Part şeritleri (Studio'da texture upload sonrası Material/Decal ile zenginleştirilir)
	Paths = {
		-- Spawn (0,0) → hub bahçe (0,28)
		{ x = 0, z = 10, sizeX = 6, sizeZ = 20, yawDegrees = 0 },
		-- Spawn → tohum dükkânı
		{ x = -14, z = 0, sizeX = 22, sizeZ = 5, yawDegrees = 0 },
		-- Spawn → satış
		{ x = 14, z = 0, sizeX = 22, sizeZ = 5, yawDegrees = 0 },
		-- Parsel ana cadde (X ekseni)
		{ x = 0, z = -6, sizeX = 260, sizeZ = 6, yawDegrees = 0 },
	},
}

function WorldLayout.AllProps(): { PropSpec }
	local out = {}
	for _, p in WorldLayout.Hub do
		table.insert(out, p)
	end
	for _, p in WorldLayout.Scenery do
		table.insert(out, p)
	end
	return out
end

function WorldLayout.ModelNames(): { string }
	local seen: { [string]: boolean } = {}
	local out = {}
	for _, p in WorldLayout.AllProps() do
		if not seen[p.name] then
			seen[p.name] = true
			table.insert(out, p.name)
		end
	end
	table.sort(out)
	return out
end

return WorldLayout
