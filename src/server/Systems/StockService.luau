--!strict
--[[
	Server-authoritative seed shop stock.
	One restock roll per server every Shop.RESTOCK_SECONDS; each player gets the
	full rolled quantity for that window (no competing over stock between kids).
	Pity guarantees every seed shows up at least every `pity` restocks.
]]

local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Shop = require(game.ReplicatedStorage.Shared.Config.Shop)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local StockService = {}

StockService.rng = Random.new() :: any

local state = {
	windowId = 0,
	nextRestockAt = 0,
	stock = {} :: { [string]: number },
	missed = {} :: { [string]: number },
}
local purchases: { [number]: { windowId: number, bought: { [string]: number } } } = {}

function StockService.Reset()
	state.windowId = 0
	state.nextRestockAt = 0
	state.stock = {}
	state.missed = {}
	table.clear(purchases)
end

function StockService.Restock(now: number)
	local rng = StockService.rng
	for _, seed in Seeds.ListOrdered() do
		local rule = Shop.Rule(seed.rarity)
		local missed = state.missed[seed.id] or 0
		local appears = rule.chance >= 1 or missed + 1 >= rule.pity or rng:NextNumber() < rule.chance
		if appears then
			local qty = rule.min
			if rule.max ~= rule.min and rule.max ~= math.huge then
				qty = rng:NextInteger(rule.min, rule.max)
			end
			state.stock[seed.id] = qty
			state.missed[seed.id] = 0
		else
			state.stock[seed.id] = 0
			state.missed[seed.id] = missed + 1
		end
	end
	state.windowId += 1
	state.nextRestockAt = now + Shop.RESTOCK_SECONDS
end

-- Returns true if a restock happened
function StockService.Tick(now: number): boolean
	if now >= state.nextRestockAt then
		StockService.Restock(now)
		return true
	end
	return false
end

function StockService.Remaining(userId: number, seedId: string): number
	local qty = state.stock[seedId] or 0
	if qty == math.huge then
		return qty
	end
	local p = purchases[userId]
	local bought = if p and p.windowId == state.windowId then p.bought[seedId] or 0 else 0
	return math.max(0, qty - bought)
end

function StockService.Buy(
	data: Types.PlayerData,
	userId: number,
	seedId: string,
	amount: number,
	buyFn: (Types.PlayerData, string, number) -> (boolean, string)
): (boolean, string)
	if amount ~= amount then
		return false, "Geçersiz miktar."
	end
	amount = math.floor(amount)
	if not Seeds.Get(seedId) then
		return false, "Geçersiz tohum."
	end
	local left = StockService.Remaining(userId, seedId)
	if left <= 0 then
		return false, "Bu tohum şu an rafta yok. Yeni stok birazdan gelir."
	end
	if amount > left then
		return false, string.format("Rafta sadece %d tane var.", left)
	end
	local ok, msg = buyFn(data, seedId, amount)
	if ok and left ~= math.huge then
		local p = purchases[userId]
		if not p or p.windowId ~= state.windowId then
			p = { windowId = state.windowId, bought = {} }
			purchases[userId] = p
		end
		p.bought[seedId] = (p.bought[seedId] or 0) + amount
	end
	return ok, msg
end

function StockService.ClearPlayer(userId: number)
	purchases[userId] = nil
end

-- Replication snapshot: -1 = unlimited
function StockService.Snapshot(userId: number, now: number)
	local items = {}
	for _, seed in Seeds.ListOrdered() do
		local r = StockService.Remaining(userId, seed.id)
		items[seed.id] = if r == math.huge then -1 else r
	end
	return {
		items = items,
		secondsLeft = math.max(0, state.nextRestockAt - now),
	}
end

function StockService._state()
	return state
end

return StockService
