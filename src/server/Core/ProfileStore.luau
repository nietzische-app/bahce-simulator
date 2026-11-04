--!strict
--[[
	Lightweight ProfileService-like DataStore wrapper:
	- session locking
	- retry with backoff
	- reconcile defaults
	Reusable core for future sims.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local GameConfig = require(game.ReplicatedStorage.Shared.Config.Game)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local ProfileStore = {}
ProfileStore.__index = ProfileStore

export type Profile = {
	Data: Types.PlayerData,
	Key: string,
	UserId: number,
	_store: any,
	_sessionId: string,
	_released: boolean,
	_saving: boolean,
}

local DEFAULT_DATA: Types.PlayerData = {
	coins = GameConfig.STARTING_COINS,
	inventory = {},
	plants = {},
	upgrades = {
		extraSlots = 0,
		growthSpeedLevel = 0,
	},
	ownedGamepasses = {},
	purchaseHistory = {},
	lastDailyClaim = 0,
	totalHarvested = 0,
	totalEarned = 0,
	plotIndex = nil,
	sessionLockId = nil,
	sessionLockExpires = nil,
	dataVersion = GameConfig.DATA_VERSION,
}

local function deepCopy<T>(value: T): T
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for k, v in pairs(value :: any) do
		result[k] = deepCopy(v)
	end
	return result :: any
end

local function reconcile(data: any): Types.PlayerData
	local out = deepCopy(DEFAULT_DATA)
	if typeof(data) ~= "table" then
		for seedId, count in pairs(GameConfig.STARTING_SEEDS) do
			out.inventory[seedId] = count
		end
		return out
	end
	for key, defaultValue in pairs(DEFAULT_DATA) do
		local incoming = data[key]
		if incoming == nil then
			continue
		end
		if typeof(defaultValue) == "table" and typeof(incoming) == "table" then
			if key == "upgrades" then
				for uk, _ in pairs(defaultValue) do
					if incoming[uk] ~= nil then
						out[key][uk] = incoming[uk]
					end
				end
			else
				-- inventory, ownedGamepasses, plants, purchaseHistory, etc.
				out[key] = incoming
			end
		else
			out[key] = incoming
		end
	end
	-- First-time inventory seed
	local hasAny = false
	for _, c in pairs(out.inventory) do
		if c > 0 then
			hasAny = true
			break
		end
	end
	if not hasAny and out.totalHarvested == 0 and out.totalEarned == 0 then
		for seedId, count in pairs(GameConfig.STARTING_SEEDS) do
			out.inventory[seedId] = count
		end
	end
	out.dataVersion = GameConfig.DATA_VERSION
	return out
end

local function retryAsync(label: string, maxAttempts: number, fn: () -> any): (boolean, any)
	local lastErr = nil
	for attempt = 1, maxAttempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end
		lastErr = result
		warn(string.format("[ProfileStore] %s failed (%d/%d): %s", label, attempt, maxAttempts, tostring(result)))
		task.wait(math.min(8, 0.4 * (2 ^ (attempt - 1))))
	end
	return false, lastErr
end

function ProfileStore.new(storeName: string)
	local self = setmetatable({
		_store = require(script.Parent.SafeDataStore).Get(storeName),
		_profiles = {} :: { [number]: Profile },
	}, ProfileStore)
	return self
end

function ProfileStore:_key(userId: number): string
	return "Player_" .. tostring(userId)
end

function ProfileStore:Load(player: Player): Profile?
	local userId = player.UserId
	local key = self:_key(userId)
	local sessionId = HttpService:GenerateGUID(false)
	local now = os.time()
	local lockSeconds = GameConfig.SESSION_LOCK_SECONDS

	local success, profileData = retryAsync("Load " .. key, 5, function()
		return self._store:UpdateAsync(key, function(old)
			local data = reconcile(old)
			local lockExpires = data.sessionLockExpires or 0
			local lockId = data.sessionLockId
			if lockId and lockId ~= sessionId and lockExpires > now then
				-- Another session holds the lock
				return nil
			end
			data.sessionLockId = sessionId
			data.sessionLockExpires = now + lockSeconds
			return data
		end)
	end)

	if not success then
		warn("[ProfileStore] Could not load for", player.Name)
		return nil
	end
	if profileData == nil then
		warn("[ProfileStore] Session locked for", player.Name)
		return nil
	end

	local profile: Profile = {
		Data = profileData,
		Key = key,
		UserId = userId,
		_store = self._store,
		_sessionId = sessionId,
		_released = false,
		_saving = false,
	}
	self._profiles[userId] = profile

	-- Heartbeat: extend lock + autosave
	task.spawn(function()
		while not profile._released and player.Parent == Players do
			task.wait(GameConfig.SAVE_INTERVAL_SECONDS)
			if profile._released then
				break
			end
			self:Save(profile, false)
		end
	end)

	return profile
end

function ProfileStore:Get(player: Player): Profile?
	return self._profiles[player.UserId]
end

function ProfileStore:Save(profile: Profile, release: boolean)
	if profile._released and not release then
		return
	end
	if profile._saving then
		return
	end
	profile._saving = true

	local now = os.time()
	local payload = deepCopy(profile.Data)
	if release then
		payload.sessionLockId = nil
		payload.sessionLockExpires = nil
	else
		payload.sessionLockId = profile._sessionId
		payload.sessionLockExpires = now + GameConfig.SESSION_LOCK_SECONDS
	end

	local ok = retryAsync("Save " .. profile.Key, 5, function()
		return self._store:UpdateAsync(profile.Key, function(old)
			local existing = reconcile(old)
			-- Only write if we still own the lock (or releasing)
			if
				existing.sessionLockId
				and existing.sessionLockId ~= profile._sessionId
				and (existing.sessionLockExpires or 0) > now
			then
				return nil -- abort
			end
			return payload
		end)
	end)

	if not ok then
		warn("[ProfileStore] Save failed for", profile.Key)
	else
		profile.Data = payload
		if release then
			profile.Data.sessionLockId = nil
			profile.Data.sessionLockExpires = nil
		end
	end

	profile._saving = false
end

function ProfileStore:Release(player: Player)
	local profile = self._profiles[player.UserId]
	if not profile or profile._released then
		return
	end
	profile._released = true
	self:Save(profile, true)
	self._profiles[player.UserId] = nil
end

function ProfileStore:HasPurchase(profile: Profile, purchaseId: string): boolean
	for _, rec in profile.Data.purchaseHistory do
		if rec.purchaseId == purchaseId then
			return true
		end
	end
	return false
end

function ProfileStore:RecordPurchase(profile: Profile, purchaseId: string, productId: number)
	table.insert(profile.Data.purchaseHistory, {
		purchaseId = purchaseId,
		productId = productId,
		boughtAt = os.time(),
	})
	-- Cap history length
	while #profile.Data.purchaseHistory > 200 do
		table.remove(profile.Data.purchaseHistory, 1)
	end
end

return ProfileStore
