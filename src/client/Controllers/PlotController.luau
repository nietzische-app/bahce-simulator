--!strict
--[[
	ProximityPrompt interactions on plot soil slots.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ProximityPromptService = game:GetService("ProximityPromptService")

local PlotController = {}

local remotesFolder: Folder
local getSelectedSeed: (() -> string?)?
local getState: (() -> any)?

function PlotController.Init(remotes: Folder, selectedSeedFn: () -> string?, stateFn: () -> any)
	remotesFolder = remotes
	getSelectedSeed = selectedSeedFn
	getState = stateFn

	ProximityPromptService.PromptTriggered:Connect(function(prompt, player)
		if player ~= Players.LocalPlayer then
			return
		end
		if prompt.Name ~= "PlotPrompt" then
			return
		end
		local soil = prompt.Parent
		if not soil or not soil:IsA("BasePart") then
			return
		end
		-- Ownership: plot must belong to local player (check ancestor label / attribute via state)
		local plotModel = soil:FindFirstAncestorWhichIsA("Model")
		if not plotModel or not string.find(plotModel.Name, "Asset_Plot_") then
			return
		end
		local idxStr = string.match(plotModel.Name, "Asset_Plot_(%d+)")
		local plotIndex = tonumber(idxStr)
		local state = if getState then getState() else nil
		local owned = false
		if state and state.plotIndexes then
			for _, pi in state.plotIndexes do
				if pi == plotIndex then
					owned = true
					break
				end
			end
		end
		if not owned then
			return
		end

		if soil:GetAttribute("Locked") == true then
			return
		end

		local slotIndex = soil:GetAttribute("SlotIndex")
		if typeof(slotIndex) ~= "number" then
			return
		end

		-- If a plant visual is ready (Neon), harvest; elseif has plant, do nothing special; else plant
		local visual = soil:FindFirstChild("Asset_PlantVisual")
		local plantEvent = remotesFolder:WaitForChild("PlantSeed") :: RemoteEvent
		local harvestEvent = remotesFolder:WaitForChild("Harvest") :: RemoteEvent

		if visual and visual:IsA("BasePart") and visual.Material == Enum.Material.Neon then
			harvestEvent:FireServer(slotIndex)
			return
		end

		if visual then
			-- Growing — try harvest anyway (server validates)
			harvestEvent:FireServer(slotIndex)
			return
		end

		local seedId = if getSelectedSeed then getSelectedSeed() else nil
		if not seedId then
			-- Default to first seed in inventory from state
			if state and state.inventory then
				for key, count in pairs(state.inventory) do
					if count > 0 and string.sub(key, 1, 5) ~= "crop:" then
						seedId = key
						break
					end
				end
			end
		end
		if seedId then
			plantEvent:FireServer(seedId, slotIndex)
		end
	end)

	-- Ensure plots folder exists for streaming
	Workspace:WaitForChild("Plots", 30)
end

return PlotController
