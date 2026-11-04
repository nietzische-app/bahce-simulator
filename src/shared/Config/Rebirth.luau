--!strict
--[[
	Yeniden doğuş (Rebirth): coin / parsel ilerlemesini sıfırla,
	kalıcı satış çarpanı + rozet kazan. Koleksiyon, dekor, petler kalır.
	Robux ile satın ALINAMAZ. Onay diyaloğu zorunlu.
]]

local Rebirth = {
	-- Her rebirth +%25 satış (1. → 1.25x, 2. → 1.50x, …)
	SELL_BONUS_PER = 0.25,
	MAX_REBIRTHS = 20,
	-- Minimum coins required to rebirth (discourage accidental early reset)
	MIN_COINS = 500,
	-- Minimum total harvested
	MIN_HARVESTED = 25,
	BADGE_PREFIX = "Bahçıvan",
	CONFIRM_PHRASE = "YENİDEN DOĞ", -- client must send this exact string
}

function Rebirth.SellMultiplier(rebirthCount: number): number
	local n = math.clamp(math.floor(rebirthCount), 0, Rebirth.MAX_REBIRTHS)
	return 1 + Rebirth.SELL_BONUS_PER * n
end

function Rebirth.BadgeName(rebirthCount: number): string
	local n = math.floor(rebirthCount)
	if n <= 0 then
		return ""
	end
	return string.format("%s ×%d", Rebirth.BADGE_PREFIX, n)
end

function Rebirth.NextMultiplier(rebirthCount: number): number
	return Rebirth.SellMultiplier(rebirthCount + 1)
end

return Rebirth
