--!strict
--[[
	Kid-friendly Models made of Parts, cylinders, spheres, and wedges.
	Used when ReplicatedStorage.Models/<Name> has no imported mesh.
	Imported meshes still win — ModelCatalog.Clone checks Models first.
	FBX files under assets/models are optional; Play stays filled either way.
]]

local Decor = require(script.Parent.Parent.Config.Decor)
local Pets = require(script.Parent.Parent.Config.Pets)
local Seeds = require(script.Parent.Parent.Config.Seeds)

local ModelFallback = {}

local HUB: { [string]: boolean } = {
	GardenPlot = true,
	SeedShopStall = true,
	SellStand = true,
	Sprinkler = true,
}

local WORLD: { [string]: boolean } = {
	WorldTree = true,
	WorldRock = true,
	WorldRocks = true,
	WorldLog = true,
	WorldFern = true,
	WorldFlowerA = true,
	WorldFlowerB = true,
	WorldFlowerC = true,
}

local GREEN = Color3.fromRGB(72, 168, 78)
local GREEN_DARK = Color3.fromRGB(46, 120, 58)
local BROWN = Color3.fromRGB(122, 78, 46)
local WOOD = Color3.fromRGB(168, 118, 70)
local SOIL = Color3.fromRGB(112, 74, 42)
local WHITE = Color3.fromRGB(248, 246, 240)
local INK = Color3.fromRGB(48, 42, 58)
local SKIN = Color3.fromRGB(255, 220, 190)
local METAL = Color3.fromRGB(150, 164, 178)
local WATER = Color3.fromRGB(90, 180, 255)
local ORANGE = Color3.fromRGB(255, 150, 40)

local function v(x: number, y: number, z: number): Vector3
	return Vector3.new(x, y, z)
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function prepare(part: BasePart, name: string, color: Color3, material: Enum.Material)
	part.Name = name
	part.Color = color
	part.Material = material
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.Massless = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
end

local function block(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	prepare(part, name, color, material)
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
	return part
end

-- Cylinder length is Size.X. This helper stands that axis up (world Y).
local function cylinderY(
	parent: Instance,
	name: string,
	diameter: number,
	height: number,
	center: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	prepare(part, name, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(height, diameter, diameter)
	part.CFrame = at(center.X, center.Y, center.Z) * CFrame.Angles(0, 0, math.rad(90))
	part.Parent = parent
	return part
end

-- yawDegrees 0 lies along X. -90 points the length toward +Z (behind a face that looks -Z).
local function cylinderAlong(
	parent: Instance,
	name: string,
	length: number,
	diameter: number,
	center: Vector3,
	yawDegrees: number,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	prepare(part, name, color, material)
	part.Shape = Enum.PartType.Cylinder
	part.Size = Vector3.new(length, diameter, diameter)
	part.CFrame = at(center.X, center.Y, center.Z) * CFrame.Angles(0, math.rad(yawDegrees), 0)
	part.Parent = parent
	return part
end

local function ball(
	parent: Instance,
	name: string,
	diameter: number,
	center: Vector3,
	color: Color3,
	material: Enum.Material
): Part
	local part = Instance.new("Part")
	prepare(part, name, color, material)
	part.Shape = Enum.PartType.Ball
	part.Size = Vector3.new(diameter, diameter, diameter)
	part.CFrame = at(center.X, center.Y, center.Z)
	part.Parent = parent
	return part
end

local function wedge(
	parent: Instance,
	name: string,
	size: Vector3,
	cf: CFrame,
	color: Color3,
	material: Enum.Material?
): WedgePart
	local part = Instance.new("WedgePart")
	prepare(part, name, color, material or Enum.Material.SmoothPlastic)
	part.Size = size
	part.CFrame = cf
	part.Parent = parent
	return part
end

local function newModel(): Model
	return Instance.new("Model")
end

local function hashHue(name: string): number
	local hue = 0
	for i = 1, #name do
		hue = (hue * 33 + string.byte(name, i)) % 360
	end
	return hue / 360
end

local function bloomOf(id: string): Color3
	local cfg = Seeds.Get(id)
	if cfg then
		return cfg.color
	end
	return Color3.fromRGB(255, 220, 120)
end

local function coatOf(id: string): Color3
	local cfg = Pets.GetPet(id)
	if cfg then
		return cfg.placeholderColor
	end
	return Color3.fromRGB(200, 180, 160)
end

local function accentOf(id: string, fallback: Color3): Color3
	local cfg = Decor.Get(id)
	if cfg then
		return cfg.placeholderColor
	end
	return fallback
end

local function eyes(model: Model, y: number, z: number, spread: number, size: number)
	for _, side in { -1, 1 } do
		local x = side * spread
		ball(model, "Eye", size, v(x, y, z), WHITE, Enum.Material.SmoothPlastic)
		ball(model, "Pupil", size * 0.42, v(x, y, z - size * 0.36), INK, Enum.Material.SmoothPlastic)
	end
end

local function bloomHead(model: Model, center: Vector3, color: Color3, radius: number)
	ball(model, "Bloom", radius * 1.15, center, color, Enum.Material.SmoothPlastic)
	for i = 0, 4 do
		local yaw = i * math.pi * 2 / 5
		local offset = v(math.cos(yaw) * radius, radius * 0.12, math.sin(yaw) * radius)
		ball(model, "Petal", radius * 0.7, center + offset, color, Enum.Material.SmoothPlastic)
	end
end

local function faceLabel(host: BasePart, text: string)
	local gui = Instance.new("SurfaceGui")
	gui.Name = "SignGui"
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(200, 80)
	gui.Parent = host
	local label = Instance.new("TextLabel")
	label.Name = "SignText"
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.TextColor3 = Color3.fromRGB(92, 52, 32)
	label.Parent = gui
end

local function buildGeneric(name: string): Model
	local model = newModel()
	local hue = hashHue(name)
	local main = Color3.fromHSV(hue, 0.48, 0.95)
	local alt = Color3.fromHSV((hue + 0.08) % 1, 0.35, 0.98)
	cylinderY(model, "Base", 1.35, 0.35, v(0, 0.18, 0), alt, Enum.Material.SmoothPlastic)
	ball(model, "Body", 1.55, v(0, 1.2, 0), main, Enum.Material.SmoothPlastic)
	wedge(model, "Cap", v(0.7, 0.55, 0.7), at(0, 2.05, 0), alt)
	return model
end

local function addSoil(model: Model, diameter: number)
	cylinderY(model, "Base", diameter, 0.26, v(0, 0.13, 0), SOIL, Enum.Material.Ground)
end

local function buildSeedling(id: string): Model
	local model = newModel()
	local bloom = bloomOf(id)
	addSoil(model, 1.05)
	cylinderY(model, "Stem", 0.2, 0.85, v(0, 0.68, 0), GREEN_DARK, Enum.Material.Grass)
	ball(model, "Leaf", 0.42, v(-0.28, 0.78, 0.02), GREEN, Enum.Material.Grass)
	ball(model, "Leaf", 0.36, v(0.24, 0.66, 0.08), GREEN, Enum.Material.Grass)
	ball(model, "Bud", 0.28, v(0, 1.22, 0), bloom, Enum.Material.SmoothPlastic)
	if id == "DewLeaf" then
		local drop = ball(model, "Dew", 0.16, v(0.24, 0.84, 0.14), Color3.fromRGB(190, 235, 255), Enum.Material.Neon)
		drop.Transparency = 0.3
	elseif id == "CloudBerry" then
		ball(model, "Berry", 0.2, v(0.16, 1.16, -0.06), bloom, Enum.Material.SmoothPlastic)
	elseif id == "StarRoot" then
		wedge(model, "Star", v(0.16, 0.28, 0.16), at(0, 1.42, 0), bloom)
	end
	return model
end

local function buildMature(id: string): Model
	local model = newModel()
	local bloom = bloomOf(id)
	addSoil(model, 1.35)
	if id == "SunBloom" then
		cylinderY(model, "Stem", 0.32, 2.15, v(0, 1.28, 0), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 0.72, v(-0.48, 1.05, 0), GREEN, Enum.Material.Grass)
		ball(model, "Leaf", 0.6, v(0.42, 1.4, 0.08), GREEN, Enum.Material.Grass)
		bloomHead(model, v(0, 2.85, 0), bloom, 0.62)
	elseif id == "DewLeaf" then
		cylinderY(model, "Stem", 0.26, 1.2, v(0, 0.8, 0), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 1.25, v(-0.15, 1.55, 0.05), GREEN, Enum.Material.Grass)
		ball(model, "Leaf", 1.05, v(0.55, 1.25, -0.1), Color3.fromRGB(90, 196, 120), Enum.Material.Grass)
		local drop = ball(model, "Dew", 0.38, v(0.15, 2.05, 0.25), Color3.fromRGB(186, 230, 255), Enum.Material.Neon)
		drop.Transparency = 0.25
	elseif id == "CloudBerry" then
		cylinderY(model, "Stem", 0.28, 0.9, v(0, 0.65, 0), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 1.2, v(0, 1.45, 0), GREEN, Enum.Material.Grass)
		ball(model, "Leaf", 0.85, v(-0.55, 1.25, 0.15), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 0.8, v(0.5, 1.2, -0.12), GREEN, Enum.Material.Grass)
		ball(model, "Berry", 0.42, v(0.05, 1.9, 0.32), bloom, Enum.Material.SmoothPlastic)
		ball(model, "Berry", 0.34, v(-0.32, 1.6, 0.12), bloom, Enum.Material.SmoothPlastic)
		ball(model, "Berry", 0.32, v(0.34, 1.52, -0.02), bloom, Enum.Material.SmoothPlastic)
		ball(model, "Berry", 0.28, v(0.02, 2.1, 0.02), WHITE, Enum.Material.SmoothPlastic)
	elseif id == "MoonPetal" then
		cylinderY(model, "Stem", 0.26, 1.7, v(0, 1.05, 0), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 0.6, v(-0.4, 0.9, 0.05), GREEN, Enum.Material.Grass)
		ball(model, "Leaf", 0.5, v(0.36, 1.15, -0.04), GREEN, Enum.Material.Grass)
		ball(model, "Bloom", 0.55, v(0, 2.15, 0), WHITE, Enum.Material.SmoothPlastic)
		for i = 0, 5 do
			local yaw = math.rad(i * 60)
			local cf = at(0, 2.15, 0) * CFrame.Angles(0, yaw, 0) * at(0, 0.05, -0.55) * CFrame.Angles(math.rad(-35), 0, 0)
			wedge(model, "Petal", v(0.28, 0.16, 0.7), cf, bloom)
		end
	elseif id == "StarRoot" then
		cylinderY(model, "Stem", 0.3, 1.85, v(0, 1.12, 0), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 0.55, v(-0.38, 0.85, 0), Color3.fromRGB(70, 170, 140), Enum.Material.Grass)
		ball(model, "Leaf", 0.5, v(0.34, 1.1, 0.06), GREEN, Enum.Material.Grass)
		ball(model, "Core", 0.48, v(0, 2.35, 0), Color3.fromRGB(255, 236, 150), Enum.Material.Neon)
		for i = 0, 4 do
			local yaw = math.rad(i * 72)
			local cf = at(0, 2.35, 0) * CFrame.Angles(0, yaw, 0) * at(0, 0.12, -0.42) * CFrame.Angles(math.rad(-65), 0, 0)
			wedge(model, "Star", v(0.28, 0.28, 0.75), cf, bloom)
		end
	else
		cylinderY(model, "Stem", 0.28, 1.6, v(0, 1.0, 0), GREEN_DARK, Enum.Material.Grass)
		ball(model, "Leaf", 0.55, v(-0.35, 0.9, 0), GREEN, Enum.Material.Grass)
		bloomHead(model, v(0, 2.15, 0), bloom, 0.5)
	end
	return model
end

local function buildPlant(id: string, stage: string): Model
	if stage == "seedling" then
		return buildSeedling(id)
	end
	return buildMature(id)
end

local function petBunny(model: Model, color: Color3)
	ball(model, "Base", 1.2, v(0, 0.68, 0.08), color, Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.82, v(0, 1.32, -0.22), color, Enum.Material.SmoothPlastic)
	local earL = cylinderY(model, "EarL", 0.18, 0.95, v(-0.2, 2.02, -0.26), color, Enum.Material.SmoothPlastic)
	local earR = cylinderY(model, "EarR", 0.18, 0.95, v(0.2, 2.02, -0.26), color, Enum.Material.SmoothPlastic)
	earL.CFrame = at(-0.2, 2.02, -0.26) * CFrame.Angles(math.rad(-8), 0, math.rad(14)) * CFrame.Angles(0, 0, math.rad(90))
	earR.CFrame = at(0.2, 2.02, -0.26) * CFrame.Angles(math.rad(-8), 0, math.rad(-14)) * CFrame.Angles(0, 0, math.rad(90))
	ball(model, "InnerEar", 0.1, v(-0.2, 2.02, -0.34), Color3.fromRGB(255, 170, 185), Enum.Material.SmoothPlastic)
	ball(model, "InnerEar", 0.1, v(0.2, 2.02, -0.34), Color3.fromRGB(255, 170, 185), Enum.Material.SmoothPlastic)
	ball(model, "Nose", 0.12, v(0, 1.26, -0.62), Color3.fromRGB(255, 140, 165), Enum.Material.SmoothPlastic)
	ball(model, "Tail", 0.32, v(0, 0.72, 0.68), WHITE, Enum.Material.SmoothPlastic)
	eyes(model, 1.42, -0.52, 0.16, 0.2)
end

local function petChick(model: Model, color: Color3)
	ball(model, "Base", 1.05, v(0, 0.62, 0), color, Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.72, v(0, 1.22, -0.18), color, Enum.Material.SmoothPlastic)
	wedge(model, "Beak", v(0.28, 0.18, 0.36), at(0, 1.16, -0.58) * CFrame.Angles(math.rad(-18), 0, 0), ORANGE)
	ball(model, "Wing", 0.38, v(-0.48, 0.7, 0.02), color, Enum.Material.SmoothPlastic)
	ball(model, "Wing", 0.38, v(0.48, 0.7, 0.02), color, Enum.Material.SmoothPlastic)
	block(model, "Foot", v(0.28, 0.1, 0.4), at(-0.16, 0.05, -0.05), ORANGE, Enum.Material.SmoothPlastic)
	block(model, "Foot", v(0.28, 0.1, 0.4), at(0.16, 0.05, -0.05), ORANGE, Enum.Material.SmoothPlastic)
	eyes(model, 1.32, -0.42, 0.14, 0.18)
end

local function petFrog(model: Model, color: Color3)
	cylinderAlong(model, "Base", 1.35, 0.82, v(0, 0.48, 0.05), 0, color, Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.72, v(0, 0.72, -0.55), color, Enum.Material.SmoothPlastic)
	ball(model, "Belly", 0.55, v(0, 0.42, -0.15), Color3.fromRGB(210, 235, 170), Enum.Material.SmoothPlastic)
	ball(model, "Foot", 0.32, v(-0.48, 0.16, 0.35), color, Enum.Material.SmoothPlastic)
	ball(model, "Foot", 0.32, v(0.48, 0.16, 0.35), color, Enum.Material.SmoothPlastic)
	eyes(model, 1.05, -0.62, 0.22, 0.28)
end

local function petFox(model: Model, color: Color3)
	cylinderAlong(model, "Base", 1.25, 0.62, v(0, 0.55, 0.1), 0, color, Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.7, v(0, 0.85, -0.62), color, Enum.Material.SmoothPlastic)
	ball(model, "Chest", 0.4, v(0, 0.58, -0.22), WHITE, Enum.Material.SmoothPlastic)
	wedge(model, "Ear", v(0.22, 0.48, 0.28), at(-0.22, 1.22, -0.62) * CFrame.Angles(math.rad(-15), 0, math.rad(10)), color)
	wedge(model, "Ear", v(0.22, 0.48, 0.28), at(0.22, 1.22, -0.62) * CFrame.Angles(math.rad(-15), 0, math.rad(-10)), color)
	cylinderAlong(model, "Tail", 1.05, 0.36, v(0, 0.7, 0.95), -90, color, Enum.Material.SmoothPlastic)
	ball(model, "TailTip", 0.4, v(0, 0.82, 1.5), WHITE, Enum.Material.SmoothPlastic)
	ball(model, "Nose", 0.12, v(0, 0.78, -0.96), INK, Enum.Material.SmoothPlastic)
	eyes(model, 0.95, -0.84, 0.14, 0.16)
end

local function petOwl(model: Model, color: Color3)
	ball(model, "Base", 1.15, v(0, 0.75, 0), color, Enum.Material.SmoothPlastic)
	ball(model, "Belly", 0.7, v(0, 0.7, -0.28), Color3.fromRGB(230, 214, 180), Enum.Material.SmoothPlastic)
	block(model, "Wing", v(0.18, 0.7, 0.55), at(-0.62, 0.75, 0.05), color, Enum.Material.SmoothPlastic)
	block(model, "Wing", v(0.18, 0.7, 0.55), at(0.62, 0.75, 0.05), color, Enum.Material.SmoothPlastic)
	wedge(model, "Beak", v(0.2, 0.18, 0.28), at(0, 0.78, -0.62) * CFrame.Angles(math.rad(-10), 0, 0), ORANGE)
	eyes(model, 0.95, -0.42, 0.22, 0.32)
end

local function petHedgehog(model: Model, color: Color3)
	ball(model, "Base", 1.15, v(0, 0.62, 0.05), color, Enum.Material.SmoothPlastic)
	ball(model, "Face", 0.55, v(0, 0.62, -0.42), SKIN, Enum.Material.SmoothPlastic)
	ball(model, "Ear", 0.18, v(-0.28, 0.95, -0.2), color, Enum.Material.SmoothPlastic)
	ball(model, "Ear", 0.18, v(0.28, 0.95, -0.2), color, Enum.Material.SmoothPlastic)
	ball(model, "Nose", 0.1, v(0, 0.58, -0.7), INK, Enum.Material.SmoothPlastic)
	for i = 0, 4 do
		local yaw = (i - 2) * 26
		local cf = at(math.sin(math.rad(yaw)) * 0.32, 1.05, 0.22) * CFrame.Angles(math.rad(-35), math.rad(yaw), 0)
		wedge(model, "Spike", v(0.22, 0.48, 0.22), cf, Color3.fromRGB(120, 86, 62))
	end
	eyes(model, 0.7, -0.62, 0.12, 0.14)
end

local function petDragon(model: Model, color: Color3)
	ball(model, "Base", 1.15, v(0, 0.7, 0.05), color, Enum.Material.SmoothPlastic)
	ball(model, "Belly", 0.62, v(0, 0.58, -0.2), Color3.fromRGB(255, 196, 170), Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.62, v(0, 1.05, -0.55), color, Enum.Material.SmoothPlastic)
	cylinderY(model, "Horn", 0.1, 0.38, v(-0.16, 1.42, -0.48), Color3.fromRGB(255, 214, 120), Enum.Material.SmoothPlastic)
	cylinderY(model, "Horn", 0.1, 0.38, v(0.16, 1.42, -0.48), Color3.fromRGB(255, 214, 120), Enum.Material.SmoothPlastic)
	wedge(
		model,
		"WingL",
		v(1.3, 0.12, 0.8),
		at(-1.0, 1.05, 0.1) * CFrame.Angles(0, math.rad(18), math.rad(26)),
		color
	)
	wedge(
		model,
		"WingR",
		v(1.3, 0.12, 0.8),
		at(1.0, 1.05, 0.1) * CFrame.Angles(0, math.rad(-18), math.rad(-26)),
		color
	)
	cylinderAlong(model, "Tail", 1.15, 0.28, v(0, 0.62, 0.9), -90, color, Enum.Material.SmoothPlastic)
	ball(model, "TailTip", 0.32, v(0, 0.78, 1.5), Color3.fromRGB(255, 214, 120), Enum.Material.SmoothPlastic)
	eyes(model, 1.12, -0.78, 0.12, 0.14)
end

local function petGeneric(model: Model, color: Color3)
	ball(model, "Base", 1.1, v(0, 0.65, 0), color, Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.7, v(0, 1.2, -0.2), color, Enum.Material.SmoothPlastic)
	eyes(model, 1.28, -0.45, 0.14, 0.18)
end

local function buildPet(id: string): Model
	local model = newModel()
	local color = coatOf(id)
	if id == "Bunny" then
		petBunny(model, color)
	elseif id == "Chick" then
		petChick(model, color)
	elseif id == "Frog" then
		petFrog(model, color)
	elseif id == "Fox" then
		petFox(model, color)
	elseif id == "Owl" then
		petOwl(model, color)
	elseif id == "Hedgehog" then
		petHedgehog(model, color)
	elseif id == "Dragon" then
		petDragon(model, color)
	else
		petGeneric(model, color)
	end
	return model
end

local function decorFence(): Model
	local model = newModel()
	local wood = accentOf("Fence", WOOD)
	block(model, "Base", v(3.8, 0.22, 0.28), at(0, 0.35, 0), wood, Enum.Material.Wood)
	block(model, "Rail", v(3.8, 0.18, 0.22), at(0, 1.35, 0), wood, Enum.Material.Wood)
	for index, x in { -1.35, -0.45, 0.45, 1.35 } do
		cylinderY(model, if index == 1 then "PostL" else "Picket", 0.22, 1.7, v(x, 0.85, 0), wood, Enum.Material.Wood)
	end
	return model
end

local function decorBench(): Model
	local model = newModel()
	local wood = accentOf("Bench", WOOD)
	for _, x in { -1.2, 1.2 } do
		for _, z in { -0.4, 0.4 } do
			block(model, "Leg", v(0.22, 0.7, 0.22), at(x, 0.35, z), wood, Enum.Material.Wood)
		end
	end
	block(model, "Base", v(3.1, 0.28, 1.15), at(0, 0.78, 0), wood, Enum.Material.Wood)
	block(model, "Back", v(3.1, 0.85, 0.18), at(0, 1.25, 0.5), wood, Enum.Material.Wood)
	return model
end

local function decorLantern(): Model
	local model = newModel()
	local metal = accentOf("Lantern", Color3.fromRGB(250, 220, 120))
	cylinderY(model, "Base", 0.28, 2.15, v(0, 1.08, 0), WOOD, Enum.Material.Wood)
	local lamp = ball(model, "Lamp", 0.7, v(0, 2.35, 0), metal, Enum.Material.Neon)
	lamp.Transparency = 0.05
	wedge(model, "Cap", v(0.55, 0.35, 0.55), at(0, 2.8, 0), WOOD)
	return model
end

local function decorFountain(): Model
	local model = newModel()
	local stone = accentOf("Fountain", Color3.fromRGB(150, 190, 230))
	cylinderY(model, "Base", 2.8, 0.7, v(0, 0.35, 0), stone, Enum.Material.Slate)
	local water = cylinderY(model, "Water", 2.2, 0.28, v(0, 0.62, 0), WATER, Enum.Material.Glass)
	water.Transparency = 0.35
	cylinderY(model, "Pillar", 0.4, 1.3, v(0, 1.15, 0), stone, Enum.Material.Slate)
	ball(model, "Spray", 0.55, v(0, 1.9, 0), WATER, Enum.Material.Neon)
	return model
end

local function decorFlowerPot(): Model
	local model = newModel()
	local clay = accentOf("FlowerPot", Color3.fromRGB(220, 110, 90))
	cylinderY(model, "Base", 1.15, 0.85, v(0, 0.42, 0), clay, Enum.Material.SmoothPlastic)
	cylinderY(model, "Rim", 1.35, 0.16, v(0, 0.9, 0), clay, Enum.Material.SmoothPlastic)
	cylinderY(model, "Soil", 1.0, 0.12, v(0, 0.98, 0), SOIL, Enum.Material.Ground)
	ball(model, "Bloom", 0.38, v(0, 1.4, 0), Color3.fromRGB(255, 120, 160), Enum.Material.SmoothPlastic)
	ball(model, "Bloom", 0.3, v(-0.28, 1.28, 0.08), Color3.fromRGB(255, 210, 80), Enum.Material.SmoothPlastic)
	ball(model, "Leaf", 0.28, v(0.26, 1.22, -0.05), GREEN, Enum.Material.Grass)
	return model
end

local function decorBirdhouse(): Model
	local model = newModel()
	local wood = accentOf("Birdhouse", Color3.fromRGB(120, 170, 220))
	cylinderY(model, "Base", 0.22, 1.7, v(0, 0.85, 0), WOOD, Enum.Material.Wood)
	block(model, "House", v(1.05, 0.85, 0.85), at(0, 2.15, 0), wood, Enum.Material.SmoothPlastic)
	wedge(model, "Roof", v(1.25, 0.45, 0.55), at(0, 2.7, -0.22) * CFrame.Angles(0, math.rad(180), 0), WOOD)
	wedge(model, "Roof", v(1.25, 0.45, 0.55), at(0, 2.7, 0.22), WOOD)
	ball(model, "Hole", 0.22, v(0, 2.15, -0.44), INK, Enum.Material.SmoothPlastic)
	ball(model, "Bird", 0.28, v(0.35, 2.05, -0.35), Color3.fromRGB(255, 214, 70), Enum.Material.SmoothPlastic)
	return model
end

local function decorGnome(): Model
	local model = newModel()
	local red = accentOf("Gnome", Color3.fromRGB(220, 60, 60))
	cylinderY(model, "Base", 0.7, 0.95, v(0, 0.48, 0), red, Enum.Material.SmoothPlastic)
	ball(model, "Head", 0.55, v(0, 1.15, 0), SKIN, Enum.Material.SmoothPlastic)
	ball(model, "Beard", 0.4, v(0, 0.95, -0.18), WHITE, Enum.Material.SmoothPlastic)
	cylinderY(model, "Hat", 0.48, 0.55, v(0, 1.55, 0), red, Enum.Material.SmoothPlastic)
	ball(model, "Pom", 0.28, v(0, 1.95, 0), red, Enum.Material.SmoothPlastic)
	ball(model, "Nose", 0.12, v(0, 1.12, -0.26), Color3.fromRGB(255, 160, 140), Enum.Material.SmoothPlastic)
	eyes(model, 1.22, -0.22, 0.1, 0.12)
	return model
end

local function decorSwing(): Model
	local model = newModel()
	local wood = accentOf("Swing", WOOD)
	cylinderY(model, "Base", 0.22, 3.1, v(-1.35, 1.55, 0), wood, Enum.Material.Wood)
	cylinderY(model, "Post", 0.22, 3.1, v(1.35, 1.55, 0), wood, Enum.Material.Wood)
	block(model, "Beam", v(3.1, 0.22, 0.22), at(0, 3.15, 0), wood, Enum.Material.Wood)
	block(model, "Rope", v(0.08, 1.35, 0.08), at(-0.45, 2.35, 0), BROWN, Enum.Material.Wood)
	block(model, "Rope", v(0.08, 1.35, 0.08), at(0.45, 2.35, 0), BROWN, Enum.Material.Wood)
	block(model, "Seat", v(1.3, 0.14, 0.55), at(0, 1.62, 0), Color3.fromRGB(230, 90, 90), Enum.Material.SmoothPlastic)
	return model
end

local function decorGeneric(id: string): Model
	local model = newModel()
	local color = accentOf(id, WOOD)
	cylinderY(model, "Base", 1.2, 0.4, v(0, 0.2, 0), color, Enum.Material.SmoothPlastic)
	ball(model, "Body", 0.9, v(0, 0.9, 0), color, Enum.Material.SmoothPlastic)
	wedge(model, "Cap", v(0.6, 0.4, 0.6), at(0, 1.45, 0), WHITE)
	return model
end

local function buildDecor(id: string): Model
	if id == "Fence" then
		return decorFence()
	elseif id == "Bench" then
		return decorBench()
	elseif id == "Lantern" then
		return decorLantern()
	elseif id == "Fountain" then
		return decorFountain()
	elseif id == "FlowerPot" then
		return decorFlowerPot()
	elseif id == "Birdhouse" then
		return decorBirdhouse()
	elseif id == "Gnome" then
		return decorGnome()
	elseif id == "Swing" then
		return decorSwing()
	end
	return decorGeneric(id)
end

local function buildTree(): Model
	local model = newModel()
	cylinderY(model, "Base", 2.3, 0.35, v(0, 0.18, 0), BROWN, Enum.Material.Wood)
	cylinderY(model, "Trunk", 1.55, 5.4, v(0, 2.9, 0), BROWN, Enum.Material.Wood)
	ball(model, "Canopy", 5.6, v(0, 7.1, 0), GREEN, Enum.Material.Grass)
	ball(model, "CanopyB", 4.2, v(0, 9.0, 0.2), GREEN_DARK, Enum.Material.Grass)
	ball(model, "CanopyC", 3.5, v(1.3, 6.5, 0.5), Color3.fromRGB(96, 190, 100), Enum.Material.Grass)
	ball(model, "Fruit", 0.45, v(1.35, 6.3, 1.15), Color3.fromRGB(255, 120, 110), Enum.Material.SmoothPlastic)
	return model
end

local function buildRock(wide: boolean): Model
	local model = newModel()
	local stone = Color3.fromRGB(148, 154, 160)
	local dark = Color3.fromRGB(118, 124, 132)
	ball(model, "Base", if wide then 2.6 else 3.1, v(0, if wide then 0.95 else 1.15, 0), stone, Enum.Material.Slate)
	ball(model, "Stone", if wide then 2.2 else 2.0, v(1.25, 0.8, 0.35), dark, Enum.Material.Slate)
	if wide then
		ball(model, "Stone", 1.7, v(-1.35, 0.65, -0.2), stone, Enum.Material.Slate)
		ball(model, "Stone", 1.35, v(0.2, 0.5, -1.15), dark, Enum.Material.Slate)
	end
	ball(model, "Moss", 0.65, v(0.15, if wide then 1.7 else 2.35, 0.25), GREEN, Enum.Material.Grass)
	return model
end

local function buildLog(): Model
	local model = newModel()
	cylinderAlong(model, "Base", 4.6, 1.15, v(0, 0.58, 0), 0, BROWN, Enum.Material.Wood)
	cylinderAlong(model, "Ring", 0.28, 1.2, v(2.2, 0.58, 0), 0, Color3.fromRGB(92, 58, 36), Enum.Material.Wood)
	wedge(model, "Branch", v(0.35, 0.35, 0.9), at(0.4, 1.05, 0.15) * CFrame.Angles(math.rad(-40), math.rad(20), 0), BROWN)
	ball(model, "Moss", 0.4, v(-0.6, 1.05, 0.15), GREEN, Enum.Material.Grass)
	return model
end

local function buildFern(): Model
	local model = newModel()
	cylinderY(model, "Base", 0.4, 0.2, v(0, 0.1, 0), GREEN_DARK, Enum.Material.Grass)
	for i = 0, 5 do
		local yaw = math.rad(i * 60)
		local cf = at(0, 0.2, 0) * CFrame.Angles(0, yaw, 0) * at(0, 0.45, -0.55) * CFrame.Angles(math.rad(-52), 0, 0)
		local color = if i % 2 == 0 then GREEN else GREEN_DARK
		wedge(model, "Frond", v(0.45, 0.12, 1.45), cf, color)
	end
	return model
end

local function buildFlower(color: Color3, extra: boolean): Model
	local model = newModel()
	cylinderY(model, "Base", 0.7, 0.18, v(0, 0.09, 0), SOIL, Enum.Material.Ground)
	cylinderY(model, "Stem", 0.16, 1.15, v(0, 0.72, 0), GREEN_DARK, Enum.Material.Grass)
	ball(model, "Leaf", 0.4, v(-0.22, 0.55, 0.04), GREEN, Enum.Material.Grass)
	bloomHead(model, v(0, 1.5, 0), color, 0.38)
	if extra then
		cylinderY(model, "Stem", 0.12, 0.8, v(0.35, 0.5, 0.15), GREEN, Enum.Material.Grass)
		ball(model, "Bloom", 0.32, v(0.4, 1.05, 0.18), color, Enum.Material.SmoothPlastic)
	end
	return model
end

local function buildWorld(name: string): Model
	if name == "WorldTree" then
		return buildTree()
	elseif name == "WorldRock" then
		return buildRock(false)
	elseif name == "WorldRocks" then
		return buildRock(true)
	elseif name == "WorldLog" then
		return buildLog()
	elseif name == "WorldFern" then
		return buildFern()
	elseif name == "WorldFlowerA" then
		return buildFlower(Color3.fromRGB(255, 120, 170), false)
	elseif name == "WorldFlowerB" then
		return buildFlower(Color3.fromRGB(255, 210, 70), true)
	elseif name == "WorldFlowerC" then
		return buildFlower(Color3.fromRGB(176, 140, 255), false)
	end
	return buildGeneric(name)
end

local function buildGardenPlot(): Model
	local model = newModel()
	block(model, "Base", v(8.4, 0.4, 8.4), at(0, 0.2, 0), SOIL, Enum.Material.Ground)
	block(model, "EdgeN", v(9.2, 0.65, 0.32), at(0, 0.38, -4.35), WOOD, Enum.Material.Wood)
	block(model, "EdgeS", v(9.2, 0.65, 0.32), at(0, 0.38, 4.35), WOOD, Enum.Material.Wood)
	block(model, "EdgeW", v(0.32, 0.65, 9.2), at(-4.35, 0.38, 0), WOOD, Enum.Material.Wood)
	block(model, "EdgeE", v(0.32, 0.65, 9.2), at(4.35, 0.38, 0), WOOD, Enum.Material.Wood)
	for _, x in { -4.35, 4.35 } do
		for _, z in { -4.35, 4.35 } do
			cylinderY(model, "Post", 0.4, 1.15, v(x, 0.58, z), WOOD, Enum.Material.Wood)
		end
	end
	ball(model, "Sprout", 0.45, v(-1.4, 0.65, 0.4), GREEN, Enum.Material.Grass)
	ball(model, "Bloom", 0.4, v(1.5, 0.75, -0.5), Color3.fromRGB(255, 130, 170), Enum.Material.SmoothPlastic)
	return model
end

local function buildStall(kind: string): Model
	local model = newModel()
	local awning = if kind == "seed" then Color3.fromRGB(230, 78, 96) else Color3.fromRGB(70, 170, 110)
	local trim = Color3.fromRGB(255, 228, 140)
	block(model, "Base", v(7.6, 0.3, 4.4), at(0, 0.15, 0), Color3.fromRGB(128, 88, 52), Enum.Material.Wood)
	block(model, "Counter", v(6.6, 2.05, 2.15), at(0, 1.28, 0.55), WOOD, Enum.Material.Wood)
	block(model, "Top", v(6.5, 0.12, 2.05), at(0, 2.36, 0.55), trim, Enum.Material.SmoothPlastic)
	cylinderY(model, "Post", 0.32, 4.3, v(-3.15, 2.2, -1.55), WOOD, Enum.Material.Wood)
	cylinderY(model, "Post", 0.32, 4.3, v(3.15, 2.2, -1.55), WOOD, Enum.Material.Wood)
	block(model, "Awning", v(7.4, 0.22, 3.5), at(0, 4.45, -0.55), awning, Enum.Material.SmoothPlastic)
	block(model, "Trim", v(7.4, 0.16, 0.28), at(0, 4.28, -2.2), trim, Enum.Material.SmoothPlastic)
	local sign = block(
		model,
		"Sign",
		v(3.3, 1.05, 0.16),
		at(0, 3.35, -1.7),
		Color3.fromRGB(255, 248, 230),
		Enum.Material.SmoothPlastic
	)
	faceLabel(sign, if kind == "seed" then "Tohum" else "Satış")
	if kind == "seed" then
		ball(model, "Sack", 0.7, v(-1.15, 2.85, 0.5), GREEN, Enum.Material.Grass)
		ball(model, "Sack", 0.55, v(0.15, 2.75, 0.65), Color3.fromRGB(255, 210, 70), Enum.Material.SmoothPlastic)
		ball(model, "Sack", 0.5, v(1.25, 2.72, 0.4), Color3.fromRGB(230, 120, 170), Enum.Material.SmoothPlastic)
	else
		block(model, "Crate", v(1.05, 0.9, 1.05), at(-1.15, 2.9, 0.5), Color3.fromRGB(186, 132, 72), Enum.Material.Wood)
		cylinderY(model, "Coin", 0.72, 0.14, v(1.15, 2.55, 0.55), Color3.fromRGB(255, 206, 70), Enum.Material.Neon)
	end
	return model
end

local function buildSprinkler(): Model
	local model = newModel()
	cylinderY(model, "Base", 1.25, 0.32, v(0, 0.16, 0), METAL, Enum.Material.Metal)
	cylinderY(model, "Pipe", 0.26, 1.45, v(0, 0.95, 0), METAL, Enum.Material.Metal)
	ball(model, "Head", 0.5, v(0, 1.8, 0), METAL, Enum.Material.Metal)
	cylinderAlong(model, "Arm", 1.05, 0.16, v(0.4, 1.78, 0), 0, METAL, Enum.Material.Metal)
	for i = 1, 4 do
		local angle = (i - 1) * math.pi / 2 + 0.4
		ball(
			model,
			"Drop" .. tostring(i),
			0.26,
			v(math.cos(angle) * 0.9, 1.5 - i * 0.1, math.sin(angle) * 0.9),
			WATER,
			Enum.Material.Neon
		)
	end
	return model
end

local function buildHub(name: string): Model
	if name == "GardenPlot" then
		return buildGardenPlot()
	elseif name == "SeedShopStall" then
		return buildStall("seed")
	elseif name == "SellStand" then
		return buildStall("sell")
	elseif name == "Sprinkler" then
		return buildSprinkler()
	end
	return buildGeneric(name)
end

local function buildFromKind(name: string, kind: string): Model
	local prefix, rest = string.match(kind, "^(%w+):(.+)$")
	if prefix == "hub" and rest then
		return buildHub(rest)
	elseif prefix == "world" and rest then
		return buildWorld(rest)
	elseif prefix == "plant" and rest then
		local id, stage = string.match(rest, "^(%a+):(%a+)$")
		return buildPlant(id or name, stage or "mature")
	elseif prefix == "pet" and rest then
		return buildPet(rest)
	elseif prefix == "decor" and rest then
		return buildDecor(rest)
	end
	return buildGeneric(name)
end

function ModelFallback.Describe(name: string): string
	if name == "" then
		return ""
	end
	if HUB[name] then
		return "hub:" .. name
	end
	if WORLD[name] then
		return "world:" .. name
	end
	local plantId, stage = string.match(name, "^(%a+)_(%a+)$")
	if plantId ~= nil and (stage == "seedling" or stage == "mature") and Seeds.Get(plantId) then
		return "plant:" .. plantId .. ":" .. stage
	end
	local petId = string.match(name, "^Pet_(%w+)$")
	if petId ~= nil and Pets.GetPet(petId) then
		return "pet:" .. petId
	end
	local decorId = string.match(name, "^Decor_(%w+)$")
	if decorId ~= nil and Decor.Get(decorId) then
		return "decor:" .. decorId
	end
	return "generic"
end

function ModelFallback.Build(name: string): Model?
	local kind = ModelFallback.Describe(name)
	if kind == "" then
		return nil
	end
	local model = buildFromKind(name, kind)
	model.Name = name
	local base = model:FindFirstChild("Base", true)
	if base and base:IsA("BasePart") then
		model.PrimaryPart = base
	else
		local anyPart = model:FindFirstChildWhichIsA("BasePart", true)
		if anyPart and anyPart:IsA("BasePart") then
			model.PrimaryPart = anyPart
		end
	end
	if string.sub(kind, 1, 4) == "pet:" then
		model.WorldPivot = CFrame.new(0, 0.9, 0)
	else
		model.WorldPivot = CFrame.new(0, 0, 0)
	end
	model:SetAttribute("ProceduralFallback", true)
	model:SetAttribute("FallbackKind", kind)
	return model
end

return ModelFallback
