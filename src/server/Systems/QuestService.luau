--!strict
--[[
	Daily quests: 3 per UTC day (server clock). Unfinished quests simply vanish
	at the next day — no penalty, no Robux skip.
]]

local Quests = require(game.ReplicatedStorage.Shared.Config.Quests)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)

local QuestService = {}

function QuestService.DayIndex(now: number): number
	return math.floor(now / 86400)
end

-- Deterministic pick of PER_DAY quests with distinct kinds
function QuestService.PickForDay(day: number): { string }
	local n = #Quests.Pool
	local order = table.create(n, 0)
	for i = 1, n do
		order[i] = i
	end
	local s = (day * 1103515245 + 12345) % 2147483648
	for i = n, 2, -1 do
		s = (s * 1103515245 + 12345) % 2147483648
		local j = (s % i) + 1
		order[i], order[j] = order[j], order[i]
	end
	local picked, kinds = {}, {}
	for _, idx in order do
		local q = Quests.Pool[idx]
		if not kinds[q.kind] then
			kinds[q.kind] = true
			table.insert(picked, q.id)
			if #picked >= Quests.PER_DAY then
				break
			end
		end
	end
	return picked
end

function QuestService.Ensure(data: any, now: number?)
	local day = QuestService.DayIndex(now or os.time())
	local q = data.quests
	if typeof(q) ~= "table" or q.day ~= day or typeof(q.list) ~= "table" then
		local list = {}
		for _, id in QuestService.PickForDay(day) do
			table.insert(list, { id = id, progress = 0, claimed = false })
		end
		data.quests = { day = day, list = list }
	end
	return data.quests
end

function QuestService.Track(data: any, kind: string, amount: number, now: number?)
	if amount ~= amount or amount <= 0 then
		return
	end
	local q = QuestService.Ensure(data, now)
	for _, entry in q.list do
		local def = Quests.Get(entry.id)
		if def and def.kind == kind and not entry.claimed then
			entry.progress = math.min(def.target, entry.progress + amount)
		end
	end
end

function QuestService.Claim(data: any, index: number, now: number?): (boolean, string)
	local q = QuestService.Ensure(data, now)
	if index ~= index or index % 1 ~= 0 then
		return false, "Geçersiz görev."
	end
	local entry = q.list[index]
	local def = entry and Quests.Get(entry.id)
	if not entry or not def then
		return false, "Geçersiz görev."
	end
	if entry.claimed then
		return false, "Bu görevin ödülünü zaten aldın."
	end
	if entry.progress < def.target then
		return false, "Görev henüz bitmedi."
	end
	entry.claimed = true
	data.coins += def.rewardCoins
	local text = string.format("Görev tamam! +%d coin", def.rewardCoins)
	if def.rewardSeed and Seeds.Get(def.rewardSeed) then
		local c = def.rewardSeedCount or 1
		data.inventory[def.rewardSeed] = (data.inventory[def.rewardSeed] or 0) + c
		text ..= string.format(" ve %dx %s", c, (Seeds.Get(def.rewardSeed) :: any).displayName)
	end
	return true, text
end

function QuestService.Serialize(data: any, now: number?)
	local q = QuestService.Ensure(data, now)
	local out = {}
	for i, entry in q.list do
		local def = Quests.Get(entry.id)
		if def then
			out[i] = {
				text = string.format(def.text, def.target),
				progress = entry.progress,
				target = def.target,
				claimed = entry.claimed,
				rewardCoins = def.rewardCoins,
			}
		end
	end
	return out
end

return QuestService
