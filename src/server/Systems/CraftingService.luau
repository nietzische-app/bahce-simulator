--!strict
--[[
	Server-validated crafting: crops + coins → gear / decor / seeds.
]]

local Crafting = require(game.ReplicatedStorage.Shared.Config.Crafting)
local Gear = require(game.ReplicatedStorage.Shared.Config.Gear)
local Decor = require(game.ReplicatedStorage.Shared.Config.Decor)
local Seeds = require(game.ReplicatedStorage.Shared.Config.Seeds)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local CraftingService = {}

local function countOf(data: Types.PlayerData, key: string): number
	return data.inventory[key] or 0
end

local function consume(data: Types.PlayerData, key: string, n: number)
	local have = countOf(data, key)
	local left = have - n
	if left <= 0 then
		data.inventory[key] = nil
	else
		data.inventory[key] = left
	end
end

function CraftingService.Craft(data: Types.PlayerData, recipeId: string): (boolean, string)
	if typeof(recipeId) ~= "string" or #recipeId > 40 then
		return false, "Geçersiz tarif."
	end
	local recipe = Crafting.Get(recipeId)
	if not recipe then
		return false, "Geçersiz tarif."
	end
	if data.coins < recipe.coinCost then
		return false, "Yeterli coin yok."
	end
	for _, ing in recipe.ingredients do
		if countOf(data, ing.key) < ing.count then
			return false, "Malzemeler yetersiz."
		end
	end
	-- Validate output exists before consuming
	if recipe.kind == "gear" and not Gear.Get(recipe.refId) then
		return false, "Geçersiz çıktı."
	elseif recipe.kind == "decor" and not Decor.Get(recipe.refId) then
		return false, "Geçersiz çıktı."
	elseif recipe.kind == "seed" and not Seeds.Get(recipe.refId) then
		return false, "Geçersiz çıktı."
	end

	data.coins -= recipe.coinCost
	for _, ing in recipe.ingredients do
		consume(data, ing.key, ing.count)
	end

	if recipe.kind == "gear" then
		if typeof(data.gear) ~= "table" then
			data.gear = {}
		end
		local bag: any = data.gear
		bag[recipe.refId] = (bag[recipe.refId] or 0) + recipe.amount
	elseif recipe.kind == "decor" then
		local d: any = data.decor
		if typeof(d) ~= "table" then
			d = { owned = {}, placed = {} }
			data.decor = d
		end
		if typeof(d.owned) ~= "table" then
			d.owned = {}
		end
		d.owned[recipe.refId] = (d.owned[recipe.refId] or 0) + recipe.amount
	elseif recipe.kind == "seed" then
		data.inventory[recipe.refId] = (data.inventory[recipe.refId] or 0) + recipe.amount
	end

	return true, string.format("%s üretildi!", recipe.displayName)
end

function CraftingService.Serialize(_data: Types.PlayerData)
	return {
		recipes = Crafting.ListOrdered(),
	}
end

return CraftingService
