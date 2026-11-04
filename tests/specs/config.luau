local T = require("../mocks/test")
local Loader = require("../mocks/loader")

return function()
	local l = Loader.new()
	local Game = l:require("ReplicatedStorage.Shared.Config.Game")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")
	local Mon = l:require("ReplicatedStorage.Shared.Config.Monetization")
	local Weather = l:require("ReplicatedStorage.Shared.Config.Weather")

	T.describe("Config", function()
		T.it("seed entries are self-consistent", function()
			for id, s in Seeds.All() do
				T.eq(s.id, id, "id key")
				T.ok(s.growTimeSeconds > 0 and s.buyPrice > 0, id)
				T.ok(s.sellPrice > s.buyPrice, id .. " sells for more than it costs")
			end
		end)

		T.it("seeds referenced by Game config exist", function()
			T.ok(Seeds.Get(Game.DAILY_REWARD_SEED), "DAILY_REWARD_SEED")
			for id in Game.STARTING_SEEDS do
				T.ok(Seeds.Get(id), "STARTING_SEEDS." .. id)
			end
		end)

		T.it("Monetization IDs are non-zero, unique and resolvable", function()
			local seen = {}
			for key, gp in Mon.Gamepasses do
				T.eq(gp.key, key)
				T.ok(gp.gamePassId ~= 0, key)
				T.ok(not seen[gp.gamePassId], "dup id")
				seen[gp.gamePassId] = true
				T.eq(Mon.GamepassById(gp.gamePassId), gp)
			end
			for key, p in Mon.DevProducts do
				T.eq(p.key, key)
				T.ok(p.productId ~= 0, key)
				T.ok(not seen[p.productId], "dup id")
				seen[p.productId] = true
				T.eq(Mon.ProductById(p.productId), p)
			end
			T.eq(Mon.GamepassById(0), nil)
		end)

		T.it("weather events have positive weights / multipliers", function()
			for _, e in Weather.All() do
				T.ok(e.weight > 0 and e.growthMultiplier > 0 and e.sellMultiplier > 0, e.id)
				T.eq(Weather.Get(e.id), e)
			end
		end)
	end)
end
