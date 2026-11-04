local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Stock = l:require("ServerScriptService.Server.Systems.StockService")
	local Econ = l:require("ServerScriptService.Server.Systems.EconomyService")
	local Shop = l:require("ReplicatedStorage.Shared.Config.Shop")
	local Seeds = l:require("ReplicatedStorage.Shared.Config.Seeds")

	local function unlucky()
		-- every chance roll fails (0.99 > all chances < 1)
		local seq = {}
		for i = 1, 2000 do
			seq[i] = 0.99
		end
		return F.Random.new(seq)
	end

	T.describe("StockService", function()
		T.it("common seeds are always unlimited", function()
			Stock.Reset()
			Stock.rng = unlucky()
			for _ = 1, 10 do
				Stock.Restock(0)
				T.eq(Stock.Remaining(1, "SunBloom"), math.huge)
				T.eq(Stock.Remaining(1, "DewLeaf"), math.huge)
			end
		end)

		T.it("pity guarantees every seed within its window even with worst luck", function()
			Stock.Reset()
			Stock.rng = unlucky()
			for _, seed in Seeds.ListOrdered() do
				local rule = Shop.Rule(seed.rarity)
				T.ok(rule.pity <= 6, seed.id .. " pity too long")
			end
			local lastSeen = {}
			for n = 1, 30 do
				Stock.Restock(n)
				for _, seed in Seeds.ListOrdered() do
					if Stock.Remaining(1, seed.id) > 0 then
						lastSeen[seed.id] = n
					end
					local gap = n - (lastSeen[seed.id] or 0)
					T.ok(gap < Shop.Rule(seed.rarity).pity, seed.id .. " missing too long")
				end
			end
		end)

		T.it("restocks on timer only", function()
			Stock.Reset()
			T.ok(Stock.Tick(1000))
			T.ok(not Stock.Tick(1000 + Shop.RESTOCK_SECONDS - 1))
			T.ok(Stock.Tick(1000 + Shop.RESTOCK_SECONDS))
			T.eq(Stock.Snapshot(1, 1000 + Shop.RESTOCK_SECONDS).secondsLeft, Shop.RESTOCK_SECONDS)
		end)

		T.it("BuySeed respects per-player stock and refreshes next window", function()
			Stock.Reset()
			Stock.Restock(0)
			local st = Stock._state()
			st.stock.StarRoot = 2
			local d = F.newData({ coins = 10000 })
			T.eq((Stock.Buy(d, 7, "StarRoot", 3, Econ.BuySeed)), false)
			T.ok((Stock.Buy(d, 7, "StarRoot", 2, Econ.BuySeed)))
			T.eq(d.inventory.StarRoot, 2)
			T.eq((Stock.Buy(d, 7, "StarRoot", 1, Econ.BuySeed)), false)
			T.eq(Stock.Remaining(8, "StarRoot"), 2, "other player unaffected")
			T.eq(Stock.Snapshot(7, 0).items.StarRoot, 0)
			T.eq(Stock.Snapshot(7, 0).items.SunBloom, -1)
			-- failed purchase (no coins) does not consume stock
			local poor = F.newData({ coins = 0 })
			T.eq((Stock.Buy(poor, 9, "StarRoot", 1, Econ.BuySeed)), false)
			T.eq(Stock.Remaining(9, "StarRoot"), 2)
			T.eq((Stock.Buy(d, 7, "StarRoot", 0 / 0, Econ.BuySeed)), false)
		end)
	end)
end
