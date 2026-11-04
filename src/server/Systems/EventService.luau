--!strict
--[[
	Seasonal events: currency from harvest, event shop, legacy "Eski Etkinlikler" after end.
	Data: data.eventCurrency = { [currencyId] = number }
]]

local Events = require(game.ReplicatedStorage.Shared.Config.Events)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)
local Gear = require(game.ReplicatedStorage.Shared.Config.Gear)
local Decor = require(game.ReplicatedStorage.Shared.Config.Decor)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)

local EventService = {}

function EventService.Ensure(data: Types.PlayerData): any
	local ec: any = (data :: any).eventCurrency
	if typeof(ec) ~= "table" then
		ec = {}
		(data :: any).eventCurrency = ec
	end
	return ec
end

function EventService.ActiveEvents(now: number): { any }
	local list = {}
	for _, e in Events.All() do
		if Events.IsActive(e, now) then
			table.insert(list, e)
		end
	end
	return list
end

function EventService.EndedEvents(now: number): { any }
	local list = {}
	for _, e in Events.All() do
		if Events.HasEnded(e, now) then
			table.insert(list, e)
		end
	end
	return list
end

-- Called on successful harvest
function EventService.OnHarvest(data: Types.PlayerData, now: number): number
	local gained = 0
	local ec = EventService.Ensure(data)
	for _, e in EventService.ActiveEvents(now) do
		ec[e.currencyId] = (ec[e.currencyId] or 0) + e.harvestCurrency
		gained += e.harvestCurrency
	end
	return gained
end

local function grantItem(
	data: Types.PlayerData,
	item: any,
	grantEgg: ((Types.PlayerData, string) -> (boolean, string))?
): (boolean, string)
	if item.kind == "seed" then
		if not Seeds.Get(item.refId) then
			return false, "Geçersiz tohum."
		end
		data.inventory[item.refId] = (data.inventory[item.refId] or 0) + item.amount
		return true, string.format("%s alındı!", item.displayName)
	elseif item.kind == "gear" then
		if not Gear.Get(item.refId) then
			return false, "Geçersiz alet."
		end
		if typeof(data.gear) ~= "table" then
			data.gear = {}
		end
		local bag: any = data.gear
		bag[item.refId] = (bag[item.refId] or 0) + item.amount
		return true, string.format("%s alındı!", item.displayName)
	elseif item.kind == "decor" then
		if not Decor.Get(item.refId) then
			return false, "Geçersiz dekor."
		end
		local d: any = data.decor
		if typeof(d) ~= "table" then
			d = { owned = {}, placed = {} }
			data.decor = d
		end
		if typeof(d.owned) ~= "table" then
			d.owned = {}
		end
		d.owned[item.refId] = (d.owned[item.refId] or 0) + item.amount
		return true, string.format("%s alındı!", item.displayName)
	elseif item.kind == "egg" then
		if not grantEgg then
			return false, "Yumurta verilemedi."
		end
		return grantEgg(data, item.refId)
	end
	return false, "Geçersiz ürün."
end

local function findShopItem(eventId: string, itemId: string): (any?, any?)
	local cfg = Events.Get(eventId)
	if not cfg then
		return nil, nil
	end
	for _, item in cfg.shop do
		if item.id == itemId then
			return cfg, item
		end
	end
	return cfg, nil
end

function EventService.BuyEvent(
	data: Types.PlayerData,
	eventId: string,
	itemId: string,
	now: number,
	grantEgg: ((Types.PlayerData, string) -> (boolean, string))?
): (boolean, string)
	if typeof(eventId) ~= "string" or typeof(itemId) ~= "string" then
		return false, "Geçersiz istek."
	end
	local cfg, item = findShopItem(eventId, itemId)
	if not cfg or not item then
		return false, "Geçersiz ürün."
	end
	if not Events.IsActive(cfg, now) then
		return false, "Bu etkinlik şu an aktif değil. Eski Etkinlikler'e bak."
	end
	local ec = EventService.Ensure(data)
	local have = ec[cfg.currencyId] or 0
	if have < item.eventCost then
		return false, string.format("Yeterli %s yok.", cfg.currencyName)
	end
	ec[cfg.currencyId] = have - item.eventCost
	local ok, msg = grantItem(data, item, grantEgg)
	if not ok then
		ec[cfg.currencyId] = have -- refund
		return false, msg
	end
	return true, msg
end

function EventService.BuyLegacy(
	data: Types.PlayerData,
	eventId: string,
	itemId: string,
	now: number,
	grantEgg: ((Types.PlayerData, string) -> (boolean, string))?
): (boolean, string)
	local cfg, item = findShopItem(eventId, itemId)
	if not cfg or not item then
		return false, "Geçersiz ürün."
	end
	if not Events.HasEnded(cfg, now) then
		return false, "Etkinlik bitmeden Eski Etkinlikler açılmaz."
	end
	if data.coins < item.legacyCoinCost then
		return false, "Yeterli coin yok."
	end
	data.coins -= item.legacyCoinCost
	local ok, msg = grantItem(data, item, grantEgg)
	if not ok then
		data.coins += item.legacyCoinCost
		return false, msg
	end
	return true, msg
end

function EventService.Serialize(data: Types.PlayerData, now: number)
	local ec = EventService.Ensure(data)
	local active = {}
	for _, e in EventService.ActiveEvents(now) do
		table.insert(active, {
			id = e.id,
			displayName = e.displayName,
			description = e.description,
			currencyId = e.currencyId,
			currencyName = e.currencyName,
			balance = ec[e.currencyId] or 0,
			endsAt = e.endUnix,
			harvestCurrency = e.harvestCurrency,
			shop = e.shop,
		})
	end
	local legacy = {}
	for _, e in EventService.EndedEvents(now) do
		table.insert(legacy, {
			id = e.id,
			displayName = e.displayName,
			description = "Eski etkinlik — ödüller coin ile hâlâ alınabilir.",
			shop = e.shop,
		})
	end
	return {
		active = active,
		legacy = legacy,
		balances = ec,
	}
end

return EventService
