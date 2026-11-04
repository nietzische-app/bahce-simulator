--!strict
--[[
	Generic token-bucket / cooldown rate limiter for remotes.
	Reusable across sims.
]]

local RateLimiter = {}
RateLimiter.__index = RateLimiter

export type RateLimiter = typeof(setmetatable(
	{} :: {
		_buckets: { [string]: { tokens: number, lastRefill: number } },
		_capacity: number,
		_refillPerSecond: number,
	},
	RateLimiter
))

function RateLimiter.new(capacity: number, refillPerSecond: number): RateLimiter
	local self = setmetatable({
		_buckets = {},
		_capacity = capacity,
		_refillPerSecond = refillPerSecond,
	}, RateLimiter)
	return self
end

function RateLimiter._key(_self: RateLimiter, player: Player, action: string): string
	return tostring(player.UserId) .. ":" .. action
end

function RateLimiter:Allow(player: Player, action: string, cost: number?): boolean
	local spend = if cost ~= nil then cost else 1
	local key = self:_key(player, action)
	local now = os.clock()
	local bucket = self._buckets[key]
	if not bucket then
		bucket = { tokens = self._capacity, lastRefill = now }
		self._buckets[key] = bucket
	end

	local elapsed = now - bucket.lastRefill
	bucket.tokens = math.min(self._capacity, bucket.tokens + elapsed * self._refillPerSecond)
	bucket.lastRefill = now

	if bucket.tokens >= spend then
		bucket.tokens -= spend
		return true
	end
	return false
end

function RateLimiter:ClearPlayer(player: Player)
	local prefix = tostring(player.UserId) .. ":"
	for key in pairs(self._buckets) do
		if string.sub(key, 1, #prefix) == prefix then
			self._buckets[key] = nil
		end
	end
end

return RateLimiter
