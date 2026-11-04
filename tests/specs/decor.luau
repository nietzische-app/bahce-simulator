local T = require("../mocks/test")
local F = require("../mocks/fixtures")

return function()
	local l = F.serverLoader()
	local Decor = l:require("ReplicatedStorage.Shared.Config.Decor")
	local DS = l:require("ServerScriptService.Server.Systems.DecorService")
	local Social = l:require("ReplicatedStorage.Shared.Config.Social")
	local LS = l:require("ServerScriptService.Server.Systems.LikeService")

	T.describe("Decor", function()
		T.it("config: coin prices, unique modelNames, 16 slots inside plot bounds", function()
			local seen = {}
			for _, d in Decor.ListOrdered() do
				T.ok(d.price > 0 and d.displayName ~= "", d.id)
				T.ok(not seen[d.modelName], "unique " .. d.modelName)
				seen[d.modelName] = true
				T.eq((d :: any).robux, nil, "no robux decor yet")
			end
			T.eq(Decor.MAX_PLACED, 16)
			for _, v in Decor.SLOTS do
				T.ok(math.abs(v.X) < 12 and math.abs(v.Z) < 12, "in bounds")
				T.ok(math.abs(v.X) > 9 or math.abs(v.Z) > 9, "outside soil area")
			end
		end)

		T.it("old profiles without decor work; buy charges coins and validates", function()
			local d = F.newData({ coins = 100 })
			T.eq(d.decor, nil)
			T.eq(DS.Serialize(d).placed[1], nil)
			T.ok((DS.Buy(d, "Fence", 2)))
			T.eq(d.coins, 100 - 2 * Decor.Items.Fence.price)
			T.eq(d.decor.owned.Fence, 2)
			T.eq((DS.Buy(d, "Fountain", 1)), false, "coins")
			T.eq((DS.Buy(d, "Nope", 1)), false)
			T.eq((DS.Buy(d, "Fence", 0 / 0)), false)
			T.eq((DS.Buy(d, "Fence", 1.5)), false)
			T.eq((DS.Buy(d, "Fence", 99)), false)
		end)

		T.it("place validates slot, occupancy, ownership count", function()
			local d = F.newData({ decor = { owned = { Fence = 1, Bench = 1 } } })
			T.ok((DS.Place(d, "Fence", 1)))
			T.eq((DS.Place(d, "Fence", 2)), false, "only own 1")
			T.eq((DS.Place(d, "Bench", 1)), false, "occupied")
			T.eq((DS.Place(d, "Bench", 0)), false)
			T.eq((DS.Place(d, "Bench", 17)), false)
			T.eq((DS.Place(d, "Bench", 2.5)), false)
			T.eq((DS.Place(d, "Bench", 0 / 0)), false)
			T.eq((DS.Place(d, "Bench", 2, 7)), false, "bad rot")
			T.eq((DS.Place(d, "Gnome", 3)), false, "not owned")
			T.ok((DS.Place(d, "Bench", 2, 1)))
			T.eq(#d.decor.placed, 2)
		end)

		T.it("max placed cap", function()
			local d = F.newData({ decor = { owned = { FlowerPot = 16, Fence = 1 } } })
			for s = 1, 16 do
				T.ok((DS.Place(d, "FlowerPot", s)))
			end
			T.eq((DS.Place(d, "Fence", 1)), false)
		end)

		T.it("move and remove", function()
			local d = F.newData({ decor = { owned = { Fence = 2 } } })
			DS.Place(d, "Fence", 1)
			DS.Place(d, "Fence", 2)
			T.eq((DS.Move(d, 1, 2)), false, "target full")
			T.ok((DS.Move(d, 1, 5, 3)))
			T.eq(d.decor.placed[1].slot, 5)
			T.eq(d.decor.placed[1].rot, 3)
			T.ok((DS.Move(d, 5, 5, 0)), "rotate in place")
			T.eq((DS.Move(d, 9, 10)), false)
			T.ok((DS.Remove(d, 5)))
			T.eq((DS.Remove(d, 5)), false)
			T.eq(#d.decor.placed, 1)
			T.eq(d.decor.owned.Fence, 2, "remove keeps item")
		end)

		T.it("sanitizes tampered saved placements", function()
			local d = F.newData({
				decor = {
					owned = { Fence = 1 },
					placed = {
						{ id = "Fence", slot = 1 },
						{ id = "Fence", slot = 2 },
						{ id = "Bad", slot = 3 },
						{ id = "Fence", slot = 99 },
					},
				},
			})
			DS.Ensure(d)
			T.eq(#d.decor.placed, 1)
			T.eq(d.decor.placed[1].rot, 0)
		end)
	end)

	T.describe("Likes", function()
		local day = 86400 * 20000
		T.it("1 like per target per day, no self like, old profiles", function()
			local a, b = F.newData(), F.newData()
			T.eq(LS.Likes(b), 0)
			T.eq((LS.Like(a, a, 1, 1, day)), false, "self")
			T.ok((LS.Like(a, b, 1, 2, day)))
			T.eq(LS.Likes(b), 1)
			T.eq((LS.Like(a, b, 1, 2, day + 100)), false, "same day")
			T.ok(LS.LikedToday(a, 2, day))
			T.ok((LS.Like(a, b, 1, 2, day + 86400)), "next day")
			T.eq(LS.Likes(b), 2)
		end)

		T.it("daily give cap", function()
			local a = F.newData()
			for i = 1, Social.MAX_LIKES_GIVEN_PER_DAY do
				T.ok((LS.Like(a, F.newData(), 1, 100 + i, day)))
			end
			T.eq((LS.Like(a, F.newData(), 1, 9999, day)), false)
		end)

		T.it("only preset emoji reactions", function()
			T.ok(Social.IsReaction("🌸") and Social.IsReaction("👍") and Social.IsReaction("⭐"))
			T.eq(Social.IsReaction("merhaba"), false)
			T.eq(Social.IsReaction(5), false)
		end)
	end)
end
