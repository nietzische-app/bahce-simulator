-- Tiny test framework
local T = { results = {} }
local current = "?"

function T.describe(name: string, fn: () -> ())
	current = name
	fn()
end

function T.it(name: string, fn: () -> ())
	local ok, err = pcall(fn)
	table.insert(T.results, { name = current .. " > " .. name, ok = ok, err = err })
end

function T.eq(a, b, msg: string?)
	if a ~= b then
		error(string.format("%sexpected %s, got %s", if msg then msg .. ": " else "", tostring(b), tostring(a)), 2)
	end
end

function T.near(a: number, b: number, eps: number?, msg: string?)
	if math.abs(a - b) > (eps or 1e-9) then
		error(string.format("%sexpected ~%s, got %s", if msg then msg .. ": " else "", tostring(b), tostring(a)), 2)
	end
end

function T.ok(v, msg: string?)
	if not v then
		error(msg or "expected truthy", 2)
	end
end

return T
