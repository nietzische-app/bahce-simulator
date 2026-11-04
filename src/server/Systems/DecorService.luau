--!strict
--[[
	Server-authoritative kozmetik dekor: coin ile al, kendi parselinde yuvaya yerleştir/kaldır/taşı.
	Data: data.decor = { owned = {id -> count}, placed = { {id, slot, rot} } } (eski profillerde nil).
]]

local Decor = require(game.ReplicatedStorage.Shared.Config.Decor)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local DecorService = {}

local function validInt(n: any, lo: number, hi: number): boolean
	return typeof(n) == "number" and n == n and n == math.floor(n) and n >= lo and n <= hi
end

function DecorService.Ensure(data: Types.PlayerData): any
	local d: any = data.decor
	if typeof(d) ~= "table" then
		d = {}
		data.decor = d
	end
	if typeof(d.owned) ~= "table" then
		d.owned = {}
	end
	if typeof(d.placed) ~= "table" then
		d.placed = {}
	end
	-- Sanitize: drop unknown/out-of-range/duplicate placements
	local seen = {}
	local clean = {}
	local usedById: { [string]: number } = {}
	for _, p in d.placed do
		if
			typeof(p) == "table"
			and typeof(p.id) == "string"
			and Decor.Get(p.id)
			and validInt(p.slot, 1, Decor.MAX_PLACED)
			and not seen[p.slot]
			and (usedById[p.id] or 0) < (d.owned[p.id] or 0)
		then
			seen[p.slot] = true
			usedById[p.id] = (usedById[p.id] or 0) + 1
			table.insert(clean, { id = p.id, slot = p.slot, rot = if validInt(p.rot, 0, 3) then p.rot else 0 })
		end
	end
	d.placed = clean
	return d
end

function DecorService.Owned(data: Types.PlayerData, id: string): number
	return DecorService.Ensure(data).owned[id] or 0
end

function DecorService.PlacedCount(data: Types.PlayerData, id: string?): number
	local n = 0
	for _, p in DecorService.Ensure(data).placed do
		if id == nil or p.id == id then
			n += 1
		end
	end
	return n
end

local function findSlot(d: any, slot: number): (number?, any)
	for i, p in d.placed do
		if p.slot == slot then
			return i, p
		end
	end
	return nil, nil
end

function DecorService.Buy(data: Types.PlayerData, id: string, amount: number): (boolean, string)
	local d = DecorService.Ensure(data)
	local cfg = Decor.Get(id)
	if not cfg then
		return false, "Geçersiz dekor."
	end
	if not validInt(amount, 1, Decor.MAX_BUY_PER_REQUEST) then
		return false, "Geçersiz miktar."
	end
	local have = d.owned[id] or 0
	if have + amount > Decor.MAX_OWNED_PER_ITEM then
		return false, "Bu dekordan yeterince var."
	end
	local cost = cfg.price * amount
	if data.coins < cost then
		return false, "Yeterli coin yok."
	end
	data.coins -= cost
	d.owned[id] = have + amount
	return true, string.format("%s alındı! Dekor panelinden yerleştir.", cfg.displayName)
end

function DecorService.Place(data: Types.PlayerData, id: string, slot: number, rot: number?): (boolean, string)
	local d = DecorService.Ensure(data)
	local cfg = Decor.Get(id)
	if not cfg then
		return false, "Geçersiz dekor."
	end
	if not validInt(slot, 1, Decor.MAX_PLACED) then
		return false, "Geçersiz yer."
	end
	local r = if rot == nil then 0 else rot
	if not validInt(r, 0, 3) then
		return false, "Geçersiz yön."
	end
	if findSlot(d, slot) then
		return false, "Bu yer dolu."
	end
	if #d.placed >= Decor.MAX_PLACED then
		return false, "Dekor sınırına ulaştın."
	end
	if DecorService.PlacedCount(data, id) >= (d.owned[id] or 0) then
		return false, "Yerleştirecek " .. cfg.displayName .. " kalmadı."
	end
	table.insert(d.placed, { id = id, slot = slot, rot = r })
	return true, cfg.displayName .. " yerleştirildi!"
end

function DecorService.Remove(data: Types.PlayerData, slot: number): (boolean, string)
	local d = DecorService.Ensure(data)
	if not validInt(slot, 1, Decor.MAX_PLACED) then
		return false, "Geçersiz yer."
	end
	local i = findSlot(d, slot)
	if not i then
		return false, "Burada dekor yok."
	end
	table.remove(d.placed, i)
	return true, "Dekor kaldırıldı (çantanda duruyor)."
end

function DecorService.Move(data: Types.PlayerData, fromSlot: number, toSlot: number, rot: number?): (boolean, string)
	local d = DecorService.Ensure(data)
	if not validInt(fromSlot, 1, Decor.MAX_PLACED) or not validInt(toSlot, 1, Decor.MAX_PLACED) then
		return false, "Geçersiz yer."
	end
	local _, p = findSlot(d, fromSlot)
	if not p then
		return false, "Burada dekor yok."
	end
	local r = if rot == nil then p.rot else rot
	if not validInt(r, 0, 3) then
		return false, "Geçersiz yön."
	end
	if fromSlot ~= toSlot and findSlot(d, toSlot) then
		return false, "Hedef yer dolu."
	end
	p.slot = toSlot
	p.rot = r
	return true, "Dekor taşındı."
end

function DecorService.Serialize(data: Types.PlayerData)
	local d = DecorService.Ensure(data)
	return {
		owned = d.owned,
		placed = d.placed,
		maxPlaced = Decor.MAX_PLACED,
		items = Decor.ListOrdered(),
	}
end

return DecorService
