local T = require("../mocks/test")
local Loader = require("../mocks/loader")

-- Minimal instance doubles
local function inst(className: string, props: { [string]: any })
	local o = props
	o.ClassName = className
	o.IsA = function(self, c)
		return self.ClassName == c or (c == "BasePart" and self.ClassName == "Part")
	end
	o.GetAttribute = function(self, k)
		return (self.Attributes or {})[k]
	end
	o.FindFirstChild = function(self, n)
		return (self.Children or {})[n]
	end
	o.FindFirstAncestorWhichIsA = function(self, c)
		local p = self.Parent
		while p do
			if p:IsA(c) then
				return p
			end
			p = p.Parent
		end
		return nil
	end
	return o
end

return function()
	local l = Loader.new()
	local localPlayer = { Name = "me" }
	local handler
	local hints = {}
	local fired = {}
	l:service("Players", { LocalPlayer = localPlayer })
	l:service("Workspace", { WaitForChild = function() end })
	l:service("StarterGui", {
		SetCore = function(_, _, t)
			table.insert(hints, t.Text)
		end,
	})
	l:service("ProximityPromptService", {
		PromptTriggered = {
			Connect = function(_, fn)
				handler = fn
			end,
		},
	})
	local function remote(name)
		return {
			FireServer = function(_, ...)
				table.insert(fired, { name, ... })
			end,
		}
	end
	local remotes = {
		WaitForChild = function(_, n)
			return remote(n)
		end,
	}
	local PlotController = l:require("StarterPlayer.StarterPlayerScripts.Client.Controllers.PlotController")
	local state = { plotIndexes = { 2 }, inventory = { SunBloom = 1, ["crop:DewLeaf"] = 3 } }
	PlotController.Init(remotes, function()
		return nil
	end, function()
		return state
	end)

	local function trigger(plotName, attrs, children, player)
		local model = inst("Model", { Name = plotName })
		local soil = inst("Part", { Parent = model, Attributes = attrs, Children = children })
		local prompt = { Name = "PlotPrompt", Parent = soil }
		table.clear(fired)
		table.clear(hints)
		handler(prompt, player or localPlayer)
	end

	T.describe("PlotController", function()
		T.ok(handler, "PromptTriggered connected")
		T.it("ignores other players' prompts", function()
			trigger("Asset_Plot_2", { SlotIndex = 1 }, {}, { Name = "other" })
			T.eq(#fired, 0)
		end)
		T.it("rejects plots the player does not own", function()
			trigger("Asset_Plot_3", { SlotIndex = 1 }, {})
			T.eq(#fired, 0)
			T.eq(#hints, 1)
		end)
		T.it("rejects locked slots", function()
			trigger("Asset_Plot_2", { SlotIndex = 1, Locked = true }, {})
			T.eq(#fired, 0)
		end)
		T.it("plants first non-crop seed on owned empty slot", function()
			trigger("Asset_Plot_2", { SlotIndex = 4 }, {})
			T.eq(#fired, 1)
			T.eq(fired[1][1], "PlantSeed")
			T.eq(fired[1][2], "SunBloom")
			T.eq(fired[1][3], 4)
		end)
		T.it("harvests when a plant visual exists", function()
			trigger("Asset_Plot_2", { SlotIndex = 1 }, { Asset_PlantVisual = inst("Part", { Material = "Neon" }) })
			T.eq(fired[1][1], "Harvest")
		end)
		T.it("does not treat Asset_Plot_12 as plot 2 owner match", function()
			trigger("Asset_Plot_12", { SlotIndex = 1 }, {})
			T.eq(#fired, 0)
		end)
	end)
end
