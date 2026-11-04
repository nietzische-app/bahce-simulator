-- Executed on a real Roblox server via Open Cloud Luau Execution.
-- Returns a JSON summary string. Not part of the Rojo tree.
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Workspace = game:GetService("Workspace")

local checks = {}
local function check(name, ok, detail)
	table.insert(checks, { name = name, pass = ok and true or false, detail = tostring(detail or "") })
end

local server = ServerScriptService:FindFirstChild("Server")
local shared = ReplicatedStorage:FindFirstChild("Shared")
check("tree.server_and_shared", server ~= nil and shared ~= nil, "")

local GameConfig, Monetization
do
	local ok, err = pcall(function()
		GameConfig = require(shared.Config.Game)
		Monetization = require(shared.Config.Monetization)
		require(shared.Config.Seeds)
		require(shared.Core.RateLimiter)
	end)
	check("require.shared_modules", ok, err)
end

-- Did init.server already run (scripts usually do NOT run in execution sessions)?
task.wait(1)
local initRan = Workspace:FindFirstChild("Plots") ~= nil
local initMode = initRan and "auto" or "manual"
if not initRan then
	local ok, err = pcall(function()
		require(server.Systems.GameService).Init()
	end)
	check("require.GameService_and_Init", ok, err)
else
	check("require.GameService_and_Init", true, "init.server ran on its own")
end

local plotsFolder = Workspace:FindFirstChild("Plots")
local plotCount, promptCount, slotCount = 0, 0, 0
if plotsFolder then
	for _, m in plotsFolder:GetChildren() do
		if m:IsA("Model") then
			plotCount += 1
			if m.PrimaryPart == nil then
				check("plot.primarypart." .. m.Name, false, "no PrimaryPart")
			end
		end
	end
	for _, d in plotsFolder:GetDescendants() do
		if d:IsA("ProximityPrompt") and d.Name == "PlotPrompt" then
			promptCount += 1
		end
		if d:IsA("BasePart") and d:GetAttribute("SlotIndex") then
			slotCount += 1
		end
	end
end
local expectedPlots = GameConfig and GameConfig.PLOT_COUNT or -1
check("plots.count", plotCount == expectedPlots and plotCount > 0, string.format("%d/%d", plotCount, expectedPlots))
check("plots.prompts", promptCount > 0 and promptCount == slotCount, string.format("prompts=%d slots=%d", promptCount, slotCount))

local props = Workspace:FindFirstChild("WorldProps")
check("world.props", props ~= nil and #props:GetChildren() >= 3, props and #props:GetChildren() or "missing")
check("world.ground", Workspace:FindFirstChild("Ground") ~= nil or Workspace:FindFirstChild("Asset_WorldGround") ~= nil, "")

local expectedEvents = { "PlantSeed", "Harvest", "SellAll", "BuySeed", "BuyUpgrade", "ClaimDaily",
	"RequestState", "StateUpdate", "Notify", "PromptGamepass", "PromptProduct" }
local remotes = ReplicatedStorage:FindFirstChild("Remotes")
local missing = {}
for _, n in expectedEvents do
	local r = remotes and remotes:FindFirstChild(n)
	if not (r and r:IsA("RemoteEvent")) then
		table.insert(missing, n)
	end
end
local lb = remotes and remotes:FindFirstChild("GetLeaderboard")
if not (lb and lb:IsA("RemoteFunction")) then
	table.insert(missing, "GetLeaderboard(fn)")
end
check("remotes.expected", #missing == 0, #missing == 0 and "all present" or table.concat(missing, ","))

if Monetization then
	for key, gp in Monetization.Gamepasses do
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(gp.gamePassId, Enum.InfoType.GamePass)
		end)
		check("gamepass." .. key, ok and info ~= nil, ok and (info.Name .. " price=" .. tostring(info.PriceInRobux)) or info)
	end
	for key, p in Monetization.DevProducts do
		local ok, info = pcall(function()
			return MarketplaceService:GetProductInfo(p.productId, Enum.InfoType.Product)
		end)
		check("product." .. key, ok and info ~= nil, ok and (info.Name .. " price=" .. tostring(info.PriceInRobux)) or info)
	end
end

do
	local ok, err = pcall(function()
		local ds = DataStoreService:GetDataStore("MinikBahce_OpenCloudProbe")
		local token = HttpService:GenerateGUID(false)
		ds:SetAsync("probe", token)
		local back = ds:GetAsync("probe")
		assert(back == token, "read-back mismatch")
	end)
	check("datastore.read_write", ok, err)
end

local passed = 0
for _, c in checks do
	if c.pass then
		passed += 1
	end
end
return HttpService:JSONEncode({
	initMode = initMode,
	passed = passed,
	total = #checks,
	ok = passed == #checks,
	checks = checks,
})
