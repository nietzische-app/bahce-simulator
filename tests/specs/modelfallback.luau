local fs = require("@lune/fs")
local T = require("../mocks/test")
local F = require("../mocks/fixtures")
local Loader = require("../mocks/loader")
local Instance = require("../mocks/instance")

local function partsOf(model)
	local list = {}
	for _, child in model:GetDescendants() do
		if child:IsA("BasePart") then
			table.insert(list, child)
		end
	end
	return list
end

local function textsOf(model): { string }
	local texts = {}
	for _, child in model:GetDescendants() do
		if child:IsA("TextLabel") then
			table.insert(texts, tostring(child.Text))
		end
	end
	return texts
end

return function()
	local l = F.serverLoader()
	local Fallback = l:require("ReplicatedStorage.Shared.Core.ModelFallback")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")
	local Pets = l:require("ReplicatedStorage.Shared.Config.Pets")
	local Decor = l:require("ReplicatedStorage.Shared.Config.Decor")
	local World = l:require("ReplicatedStorage.Shared.Config.WorldLayout")

	T.describe("ModelFallback", function()
		T.it("builds a specific Part model for every referenced name", function()
			local names = {}
			local function add(name)
				T.ok(type(name) == "string" and name ~= "", "empty model name")
				names[name] = true
			end
			for _, cfg in Seeds.ListOrdered() do
				add(cfg.modelSeedling)
				add(cfg.modelMature)
				T.ok(Fallback.Describe(cfg.modelSeedling) ~= Fallback.Describe(cfg.modelMature), cfg.id)
			end
			for _, name in Pets.ModelNames() do
				add(name)
			end
			for _, name in Decor.ModelNames() do
				add(name)
			end
			for _, name in World.ModelNames() do
				add(name)
			end

			local built = {}
			for name in names do
				local kind = Fallback.Describe(name)
				T.ok(kind ~= "generic" and kind ~= "", name .. " -> " .. tostring(kind))
				local model = Fallback.Build(name)
				T.ok(model, name)
				built[name] = model
				T.eq(model.Name, name)
				T.eq(model:GetAttribute("ProceduralFallback"), true)
				T.eq(model:GetAttribute("FallbackKind"), kind)
				T.ok(model.PrimaryPart and model.PrimaryPart:IsA("BasePart"), name .. " primary")
				T.eq(model.PrimaryPart.Name, "Base", name)
				T.eq(model.PrimaryPart.Anchored, true, name)
				T.eq(model.PrimaryPart.CanCollide, false, name)
				T.ok(#partsOf(model) >= 3, name .. " parts")
				for _, text in textsOf(model) do
					T.ok(string.find(text, "FBX", 1, true) == nil, text)
				end
				local pivotY = if string.sub(kind, 1, 4) == "pet:" then 0.9 else 0
				T.near(model.WorldPivot.Y, pivotY, 0.001, name)
			end

			local seedling = built.SunBloom_seedling
			local mature = built.SunBloom_mature
			T.ok(seedling:FindFirstChild("Bud", true))
			T.eq(seedling:FindFirstChild("Bloom", true), nil)
			T.ok(mature:FindFirstChild("Bloom", true))
			T.eq(mature:FindFirstChild("Bud", true), nil)

			local canopy = built.WorldTree:FindFirstChild("Canopy", true)
			T.ok(canopy and canopy.Size.X >= 4, "tree canopy")
			local trunk = built.WorldTree:FindFirstChild("Trunk", true)
			T.eq(trunk.Shape, "Cylinder")
			T.ok(built.WorldRock:FindFirstChild("Stone", true))
			T.ok(built.Pet_Bunny:FindFirstChild("EarL", true))
			local wing = built.Pet_Dragon:FindFirstChild("WingL", true)
			T.ok(wing and wing:IsA("WedgePart"))
			T.ok(built.Decor_Fence:FindFirstChild("PostL", true))
			T.eq(built.Decor_Lantern:FindFirstChild("Lamp", true).Material, "Neon")
			T.eq(built.Sprinkler:FindFirstChild("Drop1", true).Material, "Neon")
			T.ok(built.GardenPlot:FindFirstChild("EdgeN", true))
			T.eq(table.concat(textsOf(built.SeedShopStall), " "), "Tohum")
			T.eq(table.concat(textsOf(built.SellStand), " "), "Satış")
		end)

		T.it("unknown names still build, empty names do not", function()
			T.eq(Fallback.Describe(""), "")
			T.eq(Fallback.Build(""), nil)
			T.eq(Fallback.Describe("Nope"), "generic")
			local model = Fallback.Build("Nope")
			T.eq(model:GetAttribute("FallbackKind"), "generic")
			T.ok(#partsOf(model) >= 3)
			T.eq(#textsOf(model), 0)
		end)

		T.it("imported Models win over the Part fallback", function()
			local models = Instance.new("Folder")
			models.Name = "Models"
			local template = Instance.new("Model")
			template.Name = "WorldTree"
			template:SetAttribute("Imported", true)
			template.Parent = models
			local rs = {
				FindFirstChild = function(_, childName)
					if childName == "Models" then
						return models
					end
					return nil
				end,
			}
			local catalogLoader = Loader.new()
			catalogLoader:service("ReplicatedStorage", rs)
			local Catalog = catalogLoader:require("ReplicatedStorage.Shared.Core.ModelCatalog")

			local imported = Catalog.Clone("WorldTree")
			T.eq(imported.Name, "WorldTree")
			T.eq(imported:GetAttribute("Imported"), true)
			T.eq(imported:GetAttribute("ProceduralFallback"), nil)
			T.eq(imported:FindFirstChild("Canopy", true), nil)

			local fallback = Catalog.Clone("WorldRock")
			T.eq(fallback:GetAttribute("ProceduralFallback"), true)
			T.eq(fallback:GetAttribute("Imported"), nil)
			T.ok(fallback:FindFirstChild("Stone", true))
			T.eq(Catalog.Clone(""), nil)
			T.eq(Catalog.Find("WorldRock"), nil)
			T.eq(Catalog.Find("WorldTree").Name, "WorldTree")
		end)

		T.it("play sources do not tell anyone to import FBX", function()
			local function walk(dir: string)
				for _, entry in fs.readDir(dir) do
					local path = dir .. "/" .. entry
					if fs.isFile(path) then
						if string.sub(path, -6) == ".luau" or string.sub(path, -4) == ".lua" then
							local text = fs.readFile(path)
							T.ok(string.find(text, "FBX import et", 1, true) == nil, path)
							T.ok(string.find(text, "import FBX", 1, true) == nil, path)
						end
					elseif fs.isDir(path) then
						walk(path)
					end
				end
			end
			walk("src")
		end)
	end)
end
