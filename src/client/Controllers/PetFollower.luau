--!strict
--[[
	Equipped pets follow the local player. Uses ReplicatedStorage.Models/<modelName>
	when present; otherwise a coloured placeholder Part. No code-drawn art sprites.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ModelCatalog = require(ReplicatedStorage.Shared.Core.ModelCatalog)
local Pets = require(ReplicatedStorage.Shared.Config.Pets)

local PetFollower = {}

local folder: Folder? = nil
local parts: { [string]: Instance } = {}
local conn: RBXScriptConnection? = nil

local function ensureFolder(): Folder
	if folder and folder.Parent then
		return folder
	end
	local f = Instance.new("Folder")
	f.Name = "MyPets"
	f.Parent = workspace
	folder = f
	return f
end

local function makePlaceholder(color: Color3): BasePart
	local p = Instance.new("Part")
	p.Name = "PetPlaceholder"
	p.Size = Vector3.new(1.4, 1.4, 1.4)
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CastShadow = false
	return p
end

local function spawnOne(info: any): Instance
	local clone = ModelCatalog.Clone(info.modelName)
	if clone then
		ModelCatalog.AnchorAll(clone)
		return clone
	end
	local cfg = if typeof(info.petId) == "string" then Pets.GetPet(info.petId) else nil
	local color = if cfg then cfg.placeholderColor else Color3.fromRGB(200, 180, 160)
	return makePlaceholder(color)
end

function PetFollower.Sync(equippedVisuals: { any }?)
	local root = ensureFolder()
	local want: { [string]: any } = {}
	for _, v in equippedVisuals or {} do
		if typeof(v) == "table" and typeof(v.uid) == "string" then
			want[v.uid] = v
		end
	end
	for uid, inst in parts do
		if not want[uid] then
			inst:Destroy()
			parts[uid] = nil
		end
	end
	for uid, info in want do
		if not parts[uid] then
			local inst = spawnOne(info)
			inst.Name = "Pet_" .. uid
			inst.Parent = root
			parts[uid] = inst
		end
	end
end

function PetFollower.Init()
	if conn then
		return
	end
	local offsets = {
		Vector3.new(2.5, 0.6, 2.0),
		Vector3.new(-2.5, 0.6, 2.0),
		Vector3.new(0, 0.6, 3.2),
	}
	conn = RunService.RenderStepped:Connect(function()
		local char = Players.LocalPlayer.Character
		local hrp = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			return
		end
		local i = 0
		for _, inst in parts do
			i += 1
			local off = offsets[((i - 1) % #offsets) + 1]
			local cf = hrp.CFrame * CFrame.new(off)
			ModelCatalog.PivotTo(inst, cf)
		end
	end)
end

-- silence unused Pets import warning by exposing model name helper
function PetFollower.ModelNames(): { string }
	return Pets.ModelNames()
end

return PetFollower
