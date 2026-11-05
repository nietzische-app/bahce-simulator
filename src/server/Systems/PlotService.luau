--!strict
--[[
	Builds plots and hub scenery from Parts.
	Props, plants, decor, and sprinklers prefer ReplicatedStorage.Models.
	When that mesh is missing, ModelCatalog.Clone uses ModelFallback.
]]

local Workspace = game:GetService("Workspace")
local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local ModelCatalog = require(game.ReplicatedStorage.Shared.Core.ModelCatalog)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Decor = require(game.ReplicatedStorage.Shared.Config.Decor)
local WorldLayout = require(game.ReplicatedStorage.Shared.Config.WorldLayout)

local PlotService = {}

export type PlotInfo = {
	index: number,
	model: Model,
	ownerUserId: number?,
	slotsFolder: Folder,
	sign: BasePart,
}

local plots: { PlotInfo } = {}
local byUser: { [number]: { PlotInfo } } = {}

local function makePart(name: string, size: Vector3, cframe: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Anchored = true
	p.Material = Enum.Material.Grass
	p.Color = color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildSlot(parent: Folder, slotIndex: number, origin: CFrame): BasePart
	local offset = Vector3.new(((slotIndex - 1) % 4) * 4 - 6, 0.6, math.floor((slotIndex - 1) / 4) * 4 - 4)
	local soil = makePart(
		string.format("Asset_SoilSlot_%02d", slotIndex),
		Vector3.new(3.2, 0.4, 3.2),
		origin * CFrame.new(offset),
		Color3.fromRGB(101, 67, 33),
		parent
	)
	soil.Material = Enum.Material.Ground

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PlotPrompt"
	prompt.ActionText = "Etkileşim"
	prompt.ObjectText = "Tarla Yatağı " .. tostring(slotIndex)
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = soil

	soil:SetAttribute("SlotIndex", slotIndex)
	return soil
end

function PlotService.Init()
	local folder = Workspace:FindFirstChild("Plots")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Plots"
	folder.Parent = Workspace

	-- Simple ground plane
	if not Workspace:FindFirstChild("Asset_WorldGround") then
		makePart(
			"Asset_WorldGround",
			Vector3.new(GameConfig.PLOT_COUNT * GameConfig.PLOT_SPACING + 40, 1, 80),
			CFrame.new(0, -0.5, 0),
			Color3.fromRGB(90, 160, 90),
			Workspace
		)
	end

	table.clear(plots)
	for i = 1, GameConfig.PLOT_COUNT do
		local model = Instance.new("Model")
		model.Name = string.format("Asset_Plot_%02d", i)
		model.Parent = folder

		local origin = CFrame.new((i - (GameConfig.PLOT_COUNT + 1) / 2) * GameConfig.PLOT_SPACING, 0, 0)
		local base = makePart("Asset_PlotBase", GameConfig.PLOT_SIZE, origin, Color3.fromRGB(110, 170, 100), model)

		local fenceColor = Color3.fromRGB(160, 120, 70)
		-- Simple fence posts (placeholders)
		for _, ox in { -11, 11 } do
			for _, oz in { -11, 11 } do
				makePart(
					"Asset_FencePost",
					Vector3.new(0.6, 3, 0.6),
					origin * CFrame.new(ox, 1.5, oz),
					fenceColor,
					model
				).Material =
					Enum.Material.Wood
			end
		end

		local sign = makePart(
			"Asset_PlotSign",
			Vector3.new(6, 2, 0.4),
			origin * CFrame.new(0, 3, -12),
			Color3.fromRGB(240, 230, 200),
			model
		)
		sign.Material = Enum.Material.SmoothPlastic
		local bb = Instance.new("BillboardGui")
		bb.Name = "PlotLabel"
		bb.Size = UDim2.fromOffset(200, 40)
		bb.StudsOffset = Vector3.new(0, 2, 0)
		bb.AlwaysOnTop = true
		bb.Parent = sign
		local label = Instance.new("TextLabel")
		label.Name = "Text"
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Text = "Parsel " .. tostring(i) .. " (Boş)"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBold
		label.TextColor3 = Color3.new(1, 1, 1)
		label.TextStrokeTransparency = 0.4
		label.Parent = bb

		local slotsFolder = Instance.new("Folder")
		slotsFolder.Name = "Slots"
		slotsFolder.Parent = model

		local maxSlots = GameConfig.BASE_PLOT_SLOTS + GameConfig.MAX_EXTRA_SLOTS
		for s = 1, maxSlots do
			local soil = buildSlot(slotsFolder, s, origin)
			-- Hide extra slots until upgraded (client/server will toggle)
			if s > GameConfig.BASE_PLOT_SLOTS then
				soil.Transparency = 0.6
				soil:SetAttribute("Locked", true)
			end
		end

		model.PrimaryPart = base
		local info: PlotInfo = {
			index = i,
			model = model,
			ownerUserId = nil,
			slotsFolder = slotsFolder,
			sign = sign,
		}
		plots[i] = info
	end

	print(string.format("[PlotService] Built %d placeholder plots", GameConfig.PLOT_COUNT))
	PlotService.TrySpawnWorldProps()
end

function PlotService.TrySpawnWorldProps()
	local folder = Workspace:FindFirstChild("WorldProps")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "WorldProps"
	folder.Parent = Workspace

	-- Dirt paths (Part strips; texture upload optional later)
	local pathsFolder = Instance.new("Folder")
	pathsFolder.Name = "Paths"
	pathsFolder.Parent = folder
	for i, path in WorldLayout.Paths do
		local part = Instance.new("Part")
		part.Name = string.format("Asset_Path_%02d", i)
		part.Anchored = true
		part.CanCollide = true
		part.Material = Enum.Material.Ground
		part.Color = Color3.fromRGB(120, 90, 55)
		part.Size = Vector3.new(path.sizeX, 0.35, path.sizeZ)
		local yaw = math.rad(path.yawDegrees or 0)
		part.CFrame = CFrame.new(path.x, 0.1, path.z) * CFrame.Angles(0, yaw, 0)
		part.TopSurface = Enum.SurfaceType.Smooth
		part.Parent = pathsFolder
	end

	local spawned = 0
	local procedural = 0
	local missing = 0
	for _, spec in WorldLayout.AllProps() do
		local yaw = math.rad(spec.yawDegrees or 0)
		local cframe = CFrame.new(spec.x, spec.y, spec.z) * CFrame.Angles(0, yaw, 0)
		local clone = ModelCatalog.Clone(spec.name)
		if clone then
			ModelCatalog.AnchorAll(clone)
			ModelCatalog.PivotTo(clone, cframe)
			clone.Parent = folder
			spawned += 1
			if clone:GetAttribute("ProceduralFallback") == true then
				procedural += 1
			end
		else
			missing += 1
			warn(string.format("[PlotService] World prop %q has no visual", spec.name))
		end
	end
	print(string.format("[PlotService] WorldProps placed=%d procedural=%d", spawned, procedural))
	if missing > 0 then
		warn(string.format("[PlotService] WorldProps missing=%d", missing))
	end
end

function PlotService.GetPlots(): { PlotInfo }
	return plots
end

function PlotService.GetPlot(index: number): PlotInfo?
	return plots[index]
end

function PlotService.GetOwnedPlots(userId: number): { PlotInfo }
	return byUser[userId] or {}
end

function PlotService.AssignPlot(userId: number, preferredIndex: number?): PlotInfo?
	-- Prefer previously assigned if free, else first free
	local function tryAssign(info: PlotInfo): boolean
		if info.ownerUserId == nil then
			info.ownerUserId = userId
			if not byUser[userId] then
				byUser[userId] = {}
			end
			table.insert(byUser[userId], info)
			PlotService.RefreshSign(info)
			return true
		end
		return false
	end

	if preferredIndex and plots[preferredIndex] and plots[preferredIndex].ownerUserId == nil then
		tryAssign(plots[preferredIndex])
		return plots[preferredIndex]
	end
	for _, info in plots do
		if tryAssign(info) then
			return info
		end
	end
	return nil
end

function PlotService.AssignExtraPlot(userId: number): PlotInfo?
	for _, info in plots do
		if info.ownerUserId == nil then
			info.ownerUserId = userId
			if not byUser[userId] then
				byUser[userId] = {}
			end
			table.insert(byUser[userId], info)
			PlotService.RefreshSign(info)
			return info
		end
	end
	return nil
end

function PlotService.ReleasePlots(userId: number)
	local owned = byUser[userId]
	if not owned then
		return
	end
	for _, info in owned do
		info.ownerUserId = nil
		-- Clear plant visuals
		for _, soil in info.slotsFolder:GetChildren() do
			if soil:IsA("BasePart") then
				local plant = soil:FindFirstChild("Asset_PlantVisual")
				if plant then
					plant:Destroy()
				end
			end
		end
		PlotService.SetSprinkler(info, false)
		PlotService.RenderDecor(info, {})
		info.model:SetAttribute("Likes", nil)
		PlotService.RefreshSign(info)
	end
	byUser[userId] = nil
end

function PlotService.RefreshSign(info: PlotInfo)
	local label = info.sign:FindFirstChild("PlotLabel") and info.sign.PlotLabel:FindFirstChild("Text")
	if label and label:IsA("TextLabel") then
		if info.ownerUserId then
			local player = game.Players:GetPlayerByUserId(info.ownerUserId)
			local name = if player then player.DisplayName else ("User " .. tostring(info.ownerUserId))
			local likes = info.model:GetAttribute("Likes")
			label.Text = string.format(
				"Parsel %d — %s  💚 %d",
				info.index,
				name,
				if typeof(likes) == "number" then likes else 0
			)
		else
			label.Text = string.format("Parsel %d (Boş)", info.index)
		end
	end
end

function PlotService.SetSlotLocked(info: PlotInfo, slotIndex: number, locked: boolean)
	for _, soil in info.slotsFolder:GetChildren() do
		if soil:IsA("BasePart") and soil:GetAttribute("SlotIndex") == slotIndex then
			soil:SetAttribute("Locked", locked)
			soil.Transparency = if locked then 0.6 else 0
		end
	end
end

function PlotService.UpdatePlantVisual(
	info: PlotInfo,
	slotIndex: number,
	seedColor: Color3?,
	progress: number?,
	ready: boolean?,
	seedId: string?
)
	for _, soil in info.slotsFolder:GetChildren() do
		if soil:IsA("BasePart") and soil:GetAttribute("SlotIndex") == slotIndex then
			local existing = soil:FindFirstChild("Asset_PlantVisual")
			if not seedColor then
				if existing then
					existing:Destroy()
				end
				return
			end

			local modelName: string? = nil
			if seedId then
				local cfg = Seeds.Get(seedId)
				if cfg then
					local prog = progress or 0
					if ready or prog >= 0.85 then
						modelName = cfg.modelMature
					else
						modelName = cfg.modelSeedling or cfg.modelMature
					end
				end
			end

			local progressScale = math.clamp(0.55 + (progress or 0) * 0.55, 0.5, 1.15)
			local plantCf = soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0)

			-- Clone prefers an imported mesh and otherwise builds ModelFallback.
			if modelName and modelName ~= "" then
				if existing and existing:GetAttribute("ModelName") == modelName then
					if existing:IsA("Model") then
						existing:ScaleTo(progressScale)
						ModelCatalog.PivotTo(existing, plantCf)
					end
					return
				end
				if existing then
					existing:Destroy()
				end
				local clone = ModelCatalog.Clone(modelName)
				if clone then
					clone.Name = "Asset_PlantVisual"
					clone:SetAttribute("ModelName", modelName)
					ModelCatalog.AnchorAll(clone)
					ModelCatalog.PivotTo(clone, plantCf)
					clone.Parent = soil
					if clone:IsA("Model") then
						clone:ScaleTo(progressScale)
					end
					return
				end
			end

			-- Last resort when the seed has no model name.
			local visual: BasePart
			if existing and existing:IsA("BasePart") then
				visual = existing
			else
				if existing then
					existing:Destroy()
				end
				visual = Instance.new("Part")
				visual.Name = "Asset_PlantVisual"
				visual.Anchored = true
				visual.CanCollide = false
				visual.Material = Enum.Material.SmoothPlastic
				visual.Parent = soil
			end
			local height = 0.5 + (progress or 0) * 2.5
			visual.Size = Vector3.new(1.2, height, 1.2)
			visual.Color = seedColor
			visual.CFrame = soil.CFrame * CFrame.new(0, soil.Size.Y / 2 + height / 2, 0)
			if ready then
				visual.Material = Enum.Material.Neon
			else
				visual.Material = Enum.Material.SmoothPlastic
			end
			return
		end
	end
end

-- Sprinkler visual: imported mesh when present, otherwise ModelFallback.
function PlotService.SetSprinkler(info: PlotInfo, active: boolean)
	local existing = info.model:FindFirstChild("Asset_Sprinkler")
	if not active then
		if existing then
			existing:Destroy()
		end
		return
	end
	if existing or not info.model.PrimaryPart then
		return
	end
	local basePart = info.model.PrimaryPart
	local at = basePart.CFrame * CFrame.new(0, basePart.Size.Y / 2, 0)
	local clone = ModelCatalog.Clone("Sprinkler")
	if clone then
		clone.Name = "Asset_Sprinkler"
		ModelCatalog.AnchorAll(clone)
		ModelCatalog.PivotTo(clone, at)
		clone.Parent = info.model
		return
	end
	local part = Instance.new("Part")
	part.Name = "Asset_Sprinkler"
	part.Anchored = true
	part.CanCollide = false
	part.Size = Vector3.new(1, 2, 1)
	part.Color = Color3.fromRGB(80, 140, 220)
	part.CFrame = at
	part.Parent = info.model
end

function PlotService.GetSlotPart(info: PlotInfo, slotIndex: number): BasePart?
	for _, soil in info.slotsFolder:GetChildren() do
		if soil:IsA("BasePart") and soil:GetAttribute("SlotIndex") == slotIndex then
			return soil
		end
	end
	return nil
end

function PlotService.SetLikes(info: PlotInfo, likes: number)
	info.model:SetAttribute("Likes", likes)
	PlotService.RefreshSign(info)
end

function PlotService.GetPlotForUser(userId: number): PlotInfo?
	local owned = byUser[userId]
	return if owned then owned[1] else nil
end

-- Kozmetik dekor: import edilmiş mesh varsa o, yoksa ModelFallback. Part yalnızca ikisi de yoksa.
function PlotService.RenderDecor(info: PlotInfo, placed: { any })
	local folder = info.model:FindFirstChild("Decor")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Decor"
	folder.Parent = info.model
	local base = info.model.PrimaryPart
	if not base then
		return
	end
	for _, p in placed do
		local cfg = Decor.Get(p.id)
		local offset = Decor.SLOTS[p.slot]
		if not cfg or not offset then
			continue
		end
		local at = base.CFrame * CFrame.new(offset) * CFrame.Angles(0, math.rad(90 * (p.rot or 0)), 0)
		local clone = ModelCatalog.Clone(cfg.modelName)
		if clone then
			ModelCatalog.AnchorAll(clone)
			ModelCatalog.PivotTo(clone, at)
			clone:SetAttribute("DecorSlot", p.slot)
			clone.Parent = folder
		else
			local part = Instance.new("Part")
			part.Name = "Asset_" .. cfg.modelName
			part.Anchored = true
			part.CanCollide = false
			part.CanTouch = false
			part.Size = cfg.placeholderSize
			part.Color = cfg.placeholderColor
			part.Material = Enum.Material.SmoothPlastic
			part.CFrame = at * CFrame.new(0, cfg.placeholderSize.Y / 2, 0)
			part:SetAttribute("DecorSlot", p.slot)
			part.Parent = folder
		end
	end
end

-- Hazır emoji tepkisini parsel tabelasının üstünde kısa süre gösterir (sohbet yok).
function PlotService.ShowReaction(info: PlotInfo, emoji: string)
	local bb = Instance.new("BillboardGui")
	bb.Name = "Reaction"
	bb.Size = UDim2.fromOffset(60, 60)
	bb.StudsOffset = Vector3.new(math.random(-3, 3), 5, 0)
	bb.AlwaysOnTop = true
	local t = Instance.new("TextLabel")
	t.Size = UDim2.fromScale(1, 1)
	t.BackgroundTransparency = 1
	t.Text = emoji
	t.TextScaled = true
	t.Parent = bb
	bb.Parent = info.sign
	task.delay(3, function()
		bb:Destroy()
	end)
end

return PlotService
