--!strict
--[[
	Builds N placeholder plots at runtime from Parts.
	Names follow Asset_* hooks so Studio/AI art can replace later.
]]

local Workspace = game:GetService("Workspace")
local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local ModelCatalog = require(game.ReplicatedStorage.Shared.Core.ModelCatalog)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)

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

	local props = {
		{ name = "GardenPlot", cframe = CFrame.new(0, 0, 28) },
		{ name = "SeedShopStall", cframe = CFrame.new(-28, 0, 0) },
		{ name = "SellStand", cframe = CFrame.new(28, 0, 0) },
	}
	for _, spec in props do
		local clone = ModelCatalog.Clone(spec.name)
		if clone then
			ModelCatalog.AnchorAll(clone)
			ModelCatalog.PivotTo(clone, spec.cframe)
			clone.Parent = folder
		else
			-- Named placeholder so Studio art can replace later
			local marker = Instance.new("Part")
			marker.Name = "Asset_" .. spec.name
			marker.Size = Vector3.new(6, 1, 6)
			marker.Anchored = true
			marker.Color = Color3.fromRGB(180, 160, 120)
			marker.Material = Enum.Material.Wood
			marker.CFrame = spec.cframe * CFrame.new(0, 0.5, 0)
			marker.Parent = folder
			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.fromOffset(160, 28)
			bb.StudsOffset = Vector3.new(0, 3, 0)
			bb.AlwaysOnTop = true
			bb.Parent = marker
			local label = Instance.new("TextLabel")
			label.Size = UDim2.fromScale(1, 1)
			label.BackgroundTransparency = 1
			label.Text = spec.name .. " (FBX import et)"
			label.TextScaled = true
			label.Font = Enum.Font.Gotham
			label.TextColor3 = Color3.new(1, 1, 1)
			label.Parent = bb
		end
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
			label.Text = string.format("Parsel %d — %s", info.index, name)
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

			-- Prefer imported mesh from ReplicatedStorage.Models when available
			if modelName and ModelCatalog.Find(modelName) then
				local needSwap = true
				if existing and existing:GetAttribute("ModelName") == modelName then
					needSwap = false
				end
				if needSwap then
					if existing then
						existing:Destroy()
					end
					local clone = ModelCatalog.Clone(modelName)
					if clone then
						clone.Name = "Asset_PlantVisual"
						clone:SetAttribute("ModelName", modelName)
						ModelCatalog.AnchorAll(clone)
						clone.Parent = soil
						local height = 0.8 + (progress or 0) * 1.4
						local cf = soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0)
						ModelCatalog.PivotTo(clone, cf)
						-- Scale approx by progress for seedling→mature feel when same mesh reused
						if clone:IsA("Model") then
							clone:ScaleTo(math.clamp(0.55 + (progress or 0) * 0.55, 0.5, 1.15))
						end
						existing = clone
					end
				elseif existing and existing:IsA("Model") then
					existing:ScaleTo(math.clamp(0.55 + (progress or 0) * 0.55, 0.5, 1.15))
					ModelCatalog.PivotTo(existing, soil.CFrame * CFrame.new(0, soil.Size.Y / 2, 0))
				end
				if existing then
					return
				end
			end

			-- Placeholder Part fallback (no imported mesh yet)
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

function PlotService.GetSlotPart(info: PlotInfo, slotIndex: number): BasePart?
	for _, soil in info.slotsFolder:GetChildren() do
		if soil:IsA("BasePart") and soil:GetAttribute("SlotIndex") == slotIndex then
			return soil
		end
	end
	return nil
end

return PlotService
