--!strict
--[[
	Minik Bahçe — client entry: HUD + remotes + plot prompts.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local StarterGui = game:GetService("StarterGui")

local MainHud = require(script.UI.MainHud)
local PlotController = require(script.Controllers.PlotController)
local AlbumPanels = require(script.UI.AlbumPanels)
local SocialPanels = require(script.UI.SocialPanels)
local FeaturePanels = require(script.UI.FeaturePanels)
local PetFollower = require(script.Controllers.PetFollower)

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("Remotes", 30) :: Folder

local state: any = {}

pcall(function()
	StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
end)

local hud
hud = MainHud.Create({
	onSell = function()
		(remotes:WaitForChild("SellAll") :: RemoteEvent):FireServer()
	end,
	onDaily = function()
		(remotes:WaitForChild("ClaimDaily") :: RemoteEvent):FireServer()
	end,
	onOpenLeaderboard = function()
		local fn = remotes:WaitForChild("GetLeaderboard") :: RemoteFunction
		local ok, top = pcall(function()
			return fn:InvokeServer()
		end)
		if ok and typeof(top) == "table" then
			local lines = { "—— Sıralama (Coin) ——" }
			for i, row in top do
				table.insert(lines, string.format("%d. %s — %d", i, row.name or "?", row.coins or 0))
			end
			hud.setNotify(table.concat(lines, " | "), "info")
		else
			hud.setNotify("Sıralama alınamadı.", "warn")
		end
	end,
})

local album = AlbumPanels.Create(function(seedId: string)
	(remotes:WaitForChild("ClaimCollection") :: RemoteEvent):FireServer(seedId)
end)
local social = SocialPanels.Create(remotes, function(msg: string, kind: string?)
	hud.setNotify(msg, kind)
end)
local features = FeaturePanels.Create(remotes, function(msg: string, kind: string?)
	hud.setNotify(msg, kind)
end)
PetFollower.Init()
local offlineEvent = remotes:WaitForChild("OfflineSummary") :: RemoteEvent
offlineEvent.OnClientEvent:Connect(album.showOffline)

local function applyState(s: any)
	state = s
	album.refresh(s.collection)
	social.refresh(s)
	features.refresh(s)
	local visuals = {}
	if typeof(s.pets) == "table" then
		for _, o in s.pets.owned or {} do
			if o.equipped then
				table.insert(visuals, {
					uid = o.uid,
					petId = o.petId,
					modelName = o.modelName,
				})
			end
		end
	end
	PetFollower.Sync(visuals)
	hud.setCoins(s.coins or 0)
	hud.setWeather(s.weather)
	hud.refreshInventory(s, function(gearId: string)
		(remotes:WaitForChild("UseGear") :: RemoteEvent):FireServer(gearId)
	end)
	hud.refreshQuests(s, function(index: number)
		(remotes:WaitForChild("ClaimQuest") :: RemoteEvent):FireServer(index)
	end)
	hud.refreshShop(s, {
		buySeed = function(id: string, amount: number)
			(remotes:WaitForChild("BuySeed") :: RemoteEvent):FireServer(id, amount)
		end,
		buyGear = function(id: string, amount: number)
			(remotes:WaitForChild("BuyGear") :: RemoteEvent):FireServer(id, amount)
		end,
		buyUpgrade = function(kind: string)
			(remotes:WaitForChild("BuyUpgrade") :: RemoteEvent):FireServer(kind)
		end,
		promptGamepass = function(key: string)
			(remotes:WaitForChild("PromptGamepass") :: RemoteEvent):FireServer(key)
		end,
		promptProduct = function(key: string)
			(remotes:WaitForChild("PromptProduct") :: RemoteEvent):FireServer(key)
		end,
	})
end
(remotes:WaitForChild("StateUpdate") :: RemoteEvent).OnClientEvent:Connect(applyState);
(remotes:WaitForChild("Notify") :: RemoteEvent).OnClientEvent:Connect(function(payload)
	if typeof(payload) == "table" then
		hud.setNotify(payload.message or "", payload.kind)
	elseif typeof(payload) == "string" then
		hud.setNotify(payload)
	end
end)

PlotController.Init(remotes, function()
	return (hud :: any).GetSelectedSeed and (hud :: any).GetSelectedSeed() or nil
end, function()
	return state
end, function()
	return (hud :: any).GetSelectedGear and (hud :: any).GetSelectedGear() or nil
end, function()
	(hud :: any).ClearSelectedGear()
end)

-- Request initial state
task.defer(function()
	(remotes:WaitForChild("RequestState") :: RemoteEvent):FireServer()
end)

print("[Client] Minik Bahçe HUD hazır")
