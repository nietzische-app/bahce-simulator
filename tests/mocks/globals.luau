-- Minimal Roblox datatype/global stubs used by pure-logic modules.
local Instance = require("./instance")

local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
end
function Color3.fromHSV(h, s, v)
	local function channel(n)
		local k = (n + h * 6) % 6
		return v - v * s * math.max(0, math.min(k, 4 - k, 1))
	end
	return { R = channel(5), G = channel(3), B = channel(1) }
end

-- Deterministic Random stub: returns queued numbers, else a fixed value
local Random = {}
Random.__index = Random
function Random.new(seq)
	return setmetatable({ seq = if type(seq) == "table" then seq else {}, i = 0 }, Random)
end
function Random:NextNumber(min, max)
	self.i += 1
	local v = self.seq[self.i] or 0.5
	if min then
		return min + v * (max - min)
	end
	return v
end
function Random:NextInteger(min, max)
	return math.floor(self:NextNumber(min, max + 1 - 1e-9))
end

local Vector3 = {}
Vector3.__index = Vector3
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3)
end
function Vector3.__add(a, b)
	return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

local CFrame = {}
CFrame.__index = CFrame
function CFrame.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, CFrame)
end
function CFrame.Angles()
	return CFrame.new(0, 0, 0)
end
function CFrame.__mul(a, b)
	return CFrame.new((a.X or 0) + (b.X or 0), (a.Y or 0) + (b.Y or 0), (a.Z or 0) + (b.Z or 0))
end

local function enumBag(names)
	local bag = {}
	for _, name in names do
		bag[name] = name
	end
	return bag
end

local Enum = {
	Material = enumBag({
		"Neon",
		"SmoothPlastic",
		"Grass",
		"Ground",
		"Wood",
		"Slate",
		"Metal",
		"Glass",
		"Sand",
		"Plastic",
	}),
	PartType = enumBag({ "Ball", "Cylinder", "Block" }),
	SurfaceType = enumBag({ "Smooth" }),
	NormalId = enumBag({ "Front" }),
	Font = enumBag({ "Gotham", "GothamBold" }),
	ProductPurchaseDecision = enumBag({ "NotProcessedYet", "PurchaseGranted" }),
}

local UDim2 = {}
function UDim2.fromScale(x, y)
	return { X = { Scale = x }, Y = { Scale = y } }
end
function UDim2.fromOffset(x, y)
	return { X = { Offset = x }, Y = { Offset = y } }
end

local Vector2 = {}
function Vector2.new(x, y)
	return { X = x or 0, Y = y or 0 }
end

return {
	Color3 = Color3,
	Vector3 = Vector3,
	CFrame = CFrame,
	UDim2 = UDim2,
	Vector2 = Vector2,
	Random = Random,
	Enum = Enum,
	Instance = Instance,
}
