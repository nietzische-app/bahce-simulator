--!strict
--[[
	Koleksiyon albümü: her tohum × (normal + her mutasyon) bir kayıt.
	Bir satırı (tohumun tüm varyantları) tamamlayınca küçük coin ödülü alınır.
]]

local Seeds = require(script.Parent.Seeds)
local Mutations = require(script.Parent.Mutations)

local Collection = {}

-- Satır ödülü = seed.sellPrice * REWARD_SELL_FACTOR (küçük, coin-only)
Collection.REWARD_SELL_FACTOR = 3
Collection.MIN_REWARD = 25

-- Variant list per seed: nil (normal) first, then mutations (common -> rare)
function Collection.Variants(): { string }
	local out = { "Normal" }
	for i = #Mutations.List, 1, -1 do
		table.insert(out, Mutations.List[i].id)
	end
	return out
end

function Collection.EntryKey(seedId: string, mutationId: string?): string
	return Mutations.CropKey(seedId, if mutationId == "Normal" then nil else mutationId)
end

function Collection.RowReward(seedId: string): number
	local seed = Seeds.Get(seedId)
	if not seed then
		return 0
	end
	return math.max(Collection.MIN_REWARD, seed.sellPrice * Collection.REWARD_SELL_FACTOR)
end

return Collection
