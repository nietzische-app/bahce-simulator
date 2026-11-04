--!strict
--[[
	Daily quests: 3 per UTC day, picked deterministically from the day number.
	Free rewards only; missing a day has no penalty; no Robux skip.
]]

export type QuestDef = {
	id: string,
	kind: "plant" | "harvest" | "sell" | "mutated",
	target: number,
	text: string, -- %d = target
	rewardCoins: number,
	rewardSeed: string?,
	rewardSeedCount: number?,
}

local Quests = {
	PER_DAY = 3,
	Pool = {
		{ id = "plant5", kind = "plant", target = 5, text = "%d tohum ek", rewardCoins = 20 },
		{ id = "plant10", kind = "plant", target = 10, text = "%d tohum ek", rewardCoins = 35 },
		{
			id = "harvest5",
			kind = "harvest",
			target = 5,
			text = "%d ürün hasat et",
			rewardCoins = 20,
			rewardSeed = "DewLeaf",
			rewardSeedCount = 2,
		},
		{ id = "harvest12", kind = "harvest", target = 12, text = "%d ürün hasat et", rewardCoins = 45 },
		{ id = "sell100", kind = "sell", target = 100, text = "Satarak %d coin kazan", rewardCoins = 25 },
		{
			id = "sell300",
			kind = "sell",
			target = 300,
			text = "Satarak %d coin kazan",
			rewardCoins = 40,
			rewardSeed = "CloudBerry",
			rewardSeedCount = 1,
		},
		{
			id = "mutated1",
			kind = "mutated",
			target = 1,
			text = "%d mutasyonlu ürün hasat et",
			rewardCoins = 30,
			rewardSeed = "CloudBerry",
			rewardSeedCount = 1,
		},
	} :: { QuestDef },
}

function Quests.Get(id: string): QuestDef?
	for _, q in Quests.Pool do
		if q.id == id then
			return q
		end
	end
	return nil
end

return Quests
