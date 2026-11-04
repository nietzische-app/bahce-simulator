--!strict
--[[
	Creates and exposes RemoteEvents / RemoteFunctions under ReplicatedStorage.Remotes.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Remotes = {}

local FOLDER_NAME = "Remotes"

local EVENT_NAMES = {
	"PlantSeed",
	"Harvest",
	"SellAll",
	"BuySeed",
	"BuyUpgrade",
	"BuyGear",
	"UseGear",
	"ClaimDaily",
	"ClaimQuest",
	"ClaimCollection",
	"OfflineSummary",
	"BuyDecor",
	"PlaceDecor",
	"RemoveDecor",
	"MoveDecor",
	"VisitGarden",
	"ReturnHome",
	"LikeGarden",
	"SendReaction",
	"RequestState",
	"StateUpdate",
	"Notify",
	"PromptGamepass",
	"PromptProduct",
}

local FUNCTION_NAMES = {
	"GetLeaderboard",
	"ListGardens",
}

local function ensureFolder(): Folder
	local folder = ReplicatedStorage:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = ReplicatedStorage
	end
	return folder :: Folder
end

function Remotes.Init()
	local folder = ensureFolder()
	for _, name in EVENT_NAMES do
		if not folder:FindFirstChild(name) then
			local ev = Instance.new("RemoteEvent")
			ev.Name = name
			ev.Parent = folder
		end
	end
	for _, name in FUNCTION_NAMES do
		if not folder:FindFirstChild(name) then
			local fn = Instance.new("RemoteFunction")
			fn.Name = name
			fn.Parent = folder
		end
	end
end

function Remotes.Event(name: string): RemoteEvent
	local folder = ensureFolder()
	local ev = folder:WaitForChild(name, 10)
	assert(ev and ev:IsA("RemoteEvent"), "Missing RemoteEvent: " .. name)
	return ev
end

function Remotes.Function(name: string): RemoteFunction
	local folder = ensureFolder()
	local fn = folder:WaitForChild(name, 10)
	assert(fn and fn:IsA("RemoteFunction"), "Missing RemoteFunction: " .. name)
	return fn
end

return Remotes
