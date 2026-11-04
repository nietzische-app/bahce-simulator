-- Minimal Roblox datatype/global stubs used by pure-logic modules.
local Color3 = {}
function Color3.fromRGB(r, g, b)
	return { R = r / 255, G = g / 255, B = b / 255 }
end
function Color3.new(r, g, b)
	return { R = r, G = g, B = b }
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
function Vector3.new(x, y, z)
	return { X = x or 0, Y = y or 0, Z = z or 0 }
end

local Enum = { Material = { Neon = "Neon", SmoothPlastic = "SmoothPlastic" } }

return {
	Color3 = Color3,
	Vector3 = Vector3,
	Random = Random,
	Enum = Enum,
}
