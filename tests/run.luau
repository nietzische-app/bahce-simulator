-- Headless test runner: `lune run tests/run`
local process = require("@lune/process")
local T = require("./mocks/test")

local specs = { "config", "plant", "economy", "daily", "plotcontroller", "mutations", "stock", "quests" }
for _, name in specs do
	local ok, err = pcall(function()
		require("./specs/" .. name)()
	end)
	if not ok then
		table.insert(T.results, { name = name .. " (load)", ok = false, err = err })
	end
end

local failed = 0
for _, r in T.results do
	if r.ok then
		print("PASS  " .. r.name)
	else
		failed += 1
		print("FAIL  " .. r.name .. "\n      " .. tostring(r.err))
	end
end
print(string.format("\n%d passed, %d failed", #T.results - failed, failed))
process.exit(if failed > 0 then 1 else 0)
