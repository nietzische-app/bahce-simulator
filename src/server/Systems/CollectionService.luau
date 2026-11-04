--!strict
--[[
	Server-authoritative collection album.
	data.collection: { [cropKey]: number } (first harvest unix time)
	data.collectionClaimed: { [seedId]: boolean }
	Old profiles: backfilled once from crop keys already in inventory.
]]

local Collection = require(game.ReplicatedStorage.Shared.Config.Collection)
local Mutations = require(game.ReplicatedStorage.Shared.Config.Mutations)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local CollectionService = {}

function CollectionService.Ensure(data: Types.PlayerData)
	if typeof(data.collection) ~= "table" then
		local col = {}
		for key, count in pairs(data.inventory) do
			local seedId, mut = Mutations.ParseCropKey(key)
			if seedId and Seeds.Get(seedId) and (mut == nil or Mutations.Get(mut)) and count > 0 then
				col[Mutations.CropKey(seedId, mut)] = 0
			end
		end
		data.collection = col
	end
	if typeof(data.collectionClaimed) ~= "table" then
		data.collectionClaimed = {}
	end
end

-- Returns true if this was a new album entry
function CollectionService.Record(data: Types.PlayerData, seedId: string, mutationId: string?, now: number): boolean
	CollectionService.Ensure(data)
	if not Seeds.Get(seedId) then
		return false
	end
	local key = Mutations.CropKey(seedId, mutationId)
	local col: any = data.collection
	if col[key] ~= nil then
		return false
	end
	col[key] = now
	return true
end

function CollectionService.RowProgress(data: Types.PlayerData, seedId: string): (number, number)
	CollectionService.Ensure(data)
	local col: any = data.collection
	local have, total = 0, 0
	for _, v in Collection.Variants() do
		total += 1
		if col[Collection.EntryKey(seedId, v)] ~= nil then
			have += 1
		end
	end
	return have, total
end

function CollectionService.ClaimRow(data: Types.PlayerData, seedId: string): (boolean, string)
	CollectionService.Ensure(data)
	local seed = Seeds.Get(seedId)
	if not seed then
		return false, "Geçersiz tohum."
	end
	local claimed: any = data.collectionClaimed
	if claimed[seedId] then
		return false, "Bu satırın ödülünü zaten aldın."
	end
	local have, total = CollectionService.RowProgress(data, seedId)
	if have < total then
		return false, string.format("%s satırı henüz tamamlanmadı (%d/%d).", seed.displayName, have, total)
	end
	local reward = Collection.RowReward(seedId)
	claimed[seedId] = true
	data.coins += reward
	return true, string.format("%s koleksiyonu tamam! +%d coin", seed.displayName, reward)
end

function CollectionService.Serialize(data: Types.PlayerData)
	CollectionService.Ensure(data)
	local col: any = data.collection
	local claimed: any = data.collectionClaimed
	local rows = {}
	local allHave, allTotal = 0, 0
	for _, seed in Seeds.ListOrdered() do
		local entries = {}
		for _, v in Collection.Variants() do
			local m = Mutations.Get(v)
			table.insert(entries, {
				variant = v,
				displayName = if m then m.displayName else "Normal",
				unlocked = col[Collection.EntryKey(seed.id, v)] ~= nil,
			})
		end
		local have, total = CollectionService.RowProgress(data, seed.id)
		allHave += have
		allTotal += total
		table.insert(rows, {
			seedId = seed.id,
			displayName = seed.displayName,
			assetId = seed.assetId,
			color = seed.color,
			have = have,
			total = total,
			percent = math.floor(have / total * 100),
			reward = Collection.RowReward(seed.id),
			claimed = claimed[seed.id] == true,
			entries = entries,
		})
	end
	return {
		rows = rows,
		percent = if allTotal > 0 then math.floor(allHave / allTotal * 100) else 0,
	}
end

return CollectionService
