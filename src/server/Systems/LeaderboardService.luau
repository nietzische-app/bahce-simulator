--!strict
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)

local LeaderboardService = {}

local ordered = require(script.Parent.Parent.Core.SafeDataStore).Get(GameConfig.LEADERBOARD_STORE, true)

function LeaderboardService.UpdateCoins(userId: number, coins: number)
	task.spawn(function()
		local ok, err = pcall(function()
			ordered:SetAsync(tostring(userId), math.floor(coins))
		end)
		if not ok then
			warn("[Leaderboard] Update failed:", err)
		end
	end)
end

function LeaderboardService.EnsureLeaderstats(player: Player, coins: number, harvested: number)
	local ls = player:FindFirstChild("leaderstats")
	if not ls then
		ls = Instance.new("Folder")
		ls.Name = "leaderstats"
		ls.Parent = player
	end
	local coinsVal = ls:FindFirstChild("Coins") :: IntValue?
	if not coinsVal then
		coinsVal = Instance.new("IntValue")
		coinsVal.Name = "Coins"
		coinsVal.Parent = ls
	end
	coinsVal.Value = math.floor(coins)

	local harvestVal = ls:FindFirstChild("Hasat") :: IntValue?
	if not harvestVal then
		harvestVal = Instance.new("IntValue")
		harvestVal.Name = "Hasat"
		harvestVal.Parent = ls
	end
	harvestVal.Value = math.floor(harvested)
end

function LeaderboardService.SetCoins(player: Player, coins: number)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local v = ls:FindFirstChild("Coins")
		if v and v:IsA("IntValue") then
			v.Value = math.floor(coins)
		end
	end
end

function LeaderboardService.SetHarvested(player: Player, harvested: number)
	local ls = player:FindFirstChild("leaderstats")
	if ls then
		local v = ls:FindFirstChild("Hasat")
		if v and v:IsA("IntValue") then
			v.Value = math.floor(harvested)
		end
	end
end

function LeaderboardService.GetTop(limit: number): { { userId: number, coins: number, name: string } }
	local results = {}
	local ok, pages = pcall(function()
		return ordered:GetSortedAsync(false, math.clamp(limit, 1, 50))
	end)
	if not ok or not pages then
		return results
	end
	local page = pages:GetCurrentPage()
	for _, entry in page do
		local userId = tonumber(entry.key) or 0
		local name = "Oyuncu"
		local p = Players:GetPlayerByUserId(userId)
		if p then
			name = p.DisplayName
		else
			local nok, n = pcall(function()
				return Players:GetNameFromUserIdAsync(userId)
			end)
			if nok and n then
				name = n
			end
		end
		table.insert(results, {
			userId = userId,
			coins = entry.value,
			name = name,
		})
	end
	return results
end

return LeaderboardService
