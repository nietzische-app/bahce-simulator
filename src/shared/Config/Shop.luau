--!strict
--[[
	Shop restock rules (kid-safe):
	- Stock refreshes every RESTOCK_SECONDS for free. There is NO Robux restock.
	- Common seeds are always in stock (unlimited).
	- Rarer seeds have a lower chance / quantity, but a pity counter guarantees
	  each one appears at least once every `pity` restocks, so every seed is reachable.
	- Stock is per player per restock window (players never compete for stock).
]]

export type RarityRule = {
	chance: number, -- chance to appear on a restock
	min: number, -- quantity when it appears
	max: number,
	pity: number, -- guaranteed to appear at least every N restocks
}

local Shop = {
	RESTOCK_SECONDS = 5 * 60,
	MAX_BUY_PER_REQUEST = 50,
	Rarity = {
		Common = { chance = 1, min = math.huge, max = math.huge, pity = 1 },
		Uncommon = { chance = 0.7, min = 3, max = 6, pity = 2 },
		Rare = { chance = 0.4, min = 2, max = 4, pity = 4 },
		Epic = { chance = 0.2, min = 1, max = 2, pity = 6 },
		Legendary = { chance = 0.1, min = 1, max = 1, pity = 6 },
	} :: { [string]: RarityRule },
}

function Shop.Rule(rarity: string): RarityRule
	return Shop.Rarity[rarity] or Shop.Rarity.Common
end

return Shop
