--[[
	Tiny Instance stand-in so Lune can build ModelFallback models.
	Parent assignment updates Children. Clone copies attributes only.
]]

local Instance = {}

local function isA(self, className: string): boolean
	if self.ClassName == className or className == "Instance" then
		return true
	end
	local parts = { Part = true, WedgePart = true, MeshPart = true, SpawnLocation = true }
	if className == "BasePart" and parts[self.ClassName] then
		return true
	end
	return false
end

local function new(className: string)
	local obj = {
		ClassName = className,
		Name = className,
		Children = {},
		Attributes = {},
	}

	function obj:IsA(className_: string): boolean
		return isA(self, className_)
	end

	function obj:SetAttribute(key: string, value: any)
		self.Attributes[key] = value
	end

	function obj:GetAttribute(key: string): any
		return self.Attributes[key]
	end

	function obj:GetDescendants(): { any }
		local out = {}
		local function walk(node)
			for _, child in node.Children do
				table.insert(out, child)
				walk(child)
			end
		end
		walk(self)
		return out
	end

	function obj:FindFirstChild(name: string, recursive: boolean?): any
		for _, child in self.Children do
			if child.Name == name then
				return child
			end
		end
		if recursive then
			for _, child in self.Children do
				local found = child:FindFirstChild(name, true)
				if found then
					return found
				end
			end
		end
		return nil
	end

	function obj:FindFirstChildWhichIsA(className_: string, recursive: boolean?): any
		for _, child in self.Children do
			if child:IsA(className_) then
				return child
			end
			if recursive then
				local found = child:FindFirstChildWhichIsA(className_, true)
				if found then
					return found
				end
			end
		end
		return nil
	end

	function obj:Clone()
		local copy = new(self.ClassName)
		copy.Name = self.Name
		for key, value in self.Attributes do
			copy.Attributes[key] = value
		end
		return copy
	end

	function obj:Destroy()
		self.Parent = nil
	end

	return setmetatable(obj, {
		__newindex = function(target, key, value)
			if key == "Parent" then
				local previous = rawget(target, "Parent")
				if previous and previous.Children then
					for index, child in previous.Children do
						if child == target then
							table.remove(previous.Children, index)
							break
						end
					end
				end
				rawset(target, "Parent", value)
				if value and value.Children then
					table.insert(value.Children, target)
				end
			else
				rawset(target, key, value)
			end
		end,
	})
end

function Instance.new(className: string)
	return new(className)
end

return Instance
