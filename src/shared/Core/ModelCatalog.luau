--!strict
--[[
	Looks up imported meshes under ReplicatedStorage.Models.
	Find returns that mesh only. Clone uses it when present, otherwise
	ModelFallback (Parts). FBX import is optional.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelFallback = require(script.Parent.ModelFallback)

local ModelCatalog = {}

local function modelsFolder(): Folder?
	local folder = ReplicatedStorage:FindFirstChild("Models")
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

-- Imported instance only. Missing names return nil (Clone builds a fallback).
function ModelCatalog.Find(name: string): Instance?
	if name == "" then
		return nil
	end
	local folder = modelsFolder()
	if not folder then
		return nil
	end
	local inst = folder:FindFirstChild(name)
	if inst and (inst:IsA("Model") or inst:IsA("BasePart") or inst:IsA("MeshPart")) then
		return inst
	end
	return nil
end

function ModelCatalog.Clone(name: string): Instance?
	local template = ModelCatalog.Find(name)
	if template then
		local clone = template:Clone()
		clone.Name = name
		return clone
	end
	return ModelFallback.Build(name)
end

function ModelCatalog.AnchorAll(root: Instance)
	if root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
	end
	for _, d in root:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
		end
	end
end

function ModelCatalog.GetPrimaryPart(root: Instance): BasePart?
	if root:IsA("BasePart") then
		return root
	end
	if root:IsA("Model") then
		if root.PrimaryPart then
			return root.PrimaryPart
		end
		local pp = root:FindFirstChildWhichIsA("BasePart", true)
		if pp then
			root.PrimaryPart = pp
			return pp
		end
	end
	return nil
end

function ModelCatalog.PivotTo(root: Instance, cf: CFrame)
	if root:IsA("Model") then
		root:PivotTo(cf)
		return
	end
	if root:IsA("BasePart") then
		root.CFrame = cf
	end
end

return ModelCatalog
