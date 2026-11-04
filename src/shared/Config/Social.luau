--!strict
--[[
	Bahçe ziyareti + beğeni. Çocuk güvenliği: sohbet YOK, sadece hazır emoji tepkileri.
]]

local Social = {
	-- Hedef başına günde 1 beğeni (UTC gün)
	MAX_LIKES_GIVEN_PER_DAY = 50,
	VISIT_COOLDOWN_SECONDS = 3,
	REACTION_COOLDOWN_SECONDS = 4,
	REACTIONS = { "🌸", "👍", "⭐", "🌻", "💚" },
}

function Social.IsReaction(e: any): boolean
	if typeof(e) ~= "string" then
		return false
	end
	for _, r in Social.REACTIONS do
		if r == e then
			return true
		end
	end
	return false
end

function Social.Day(now: number): number
	return math.floor(now / 86400)
end

return Social
