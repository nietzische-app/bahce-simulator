--!strict
--[[
	Beğeni: hedef başına günde 1 (UTC), kendine beğeni yok, günlük toplam sınır.
	Data: data.likes (alınan toplam), data.likesGiven = { day, targets = {userIdStr=true} }.
]]

local Social = require(game.ReplicatedStorage.Shared.Config.Social)
local Types = require(game.ReplicatedStorage.Shared.Core.Types)

local LikeService = {}

local function givenToday(data: Types.PlayerData, day: number): any
	local g: any = data.likesGiven
	if typeof(g) ~= "table" or g.day ~= day or typeof(g.targets) ~= "table" then
		g = { day = day, targets = {} }
		data.likesGiven = g
	end
	return g
end

function LikeService.Likes(data: Types.PlayerData): number
	local n = data.likes
	return if typeof(n) == "number" and n == n then math.max(0, math.floor(n)) else 0
end

function LikeService.CanLike(giver: Types.PlayerData, giverId: number, targetId: number, now: number): (boolean, string)
	if giverId == targetId then
		return false, "Kendi bahçeni beğenemezsin."
	end
	local g = givenToday(giver, Social.Day(now))
	if g.targets[tostring(targetId)] then
		return false, "Bu bahçeyi bugün zaten beğendin."
	end
	local n = 0
	for _ in g.targets do
		n += 1
	end
	if n >= Social.MAX_LIKES_GIVEN_PER_DAY then
		return false, "Bugünlük beğeni hakkın bitti."
	end
	return true, ""
end

function LikeService.Like(
	giver: Types.PlayerData,
	target: Types.PlayerData,
	giverId: number,
	targetId: number,
	now: number
): (boolean, string)
	local ok, msg = LikeService.CanLike(giver, giverId, targetId, now)
	if not ok then
		return false, msg
	end
	givenToday(giver, Social.Day(now)).targets[tostring(targetId)] = true
	target.likes = LikeService.Likes(target) + 1
	return true, "Beğeni gönderildi! 💚"
end

function LikeService.LikedToday(giver: Types.PlayerData, targetId: number, now: number): boolean
	return givenToday(giver, Social.Day(now)).targets[tostring(targetId)] == true
end

return LikeService
