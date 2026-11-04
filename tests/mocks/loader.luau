--[[
	Minimal Roblox-ish module loader for Lune.
	Maps `game.ReplicatedStorage.Shared...`, `game.ServerScriptService.Server...`,
	`game.StarterPlayer.StarterPlayerScripts.Client...` and `script.Parent...`
	to files under src/, and lets tests override any instance path with a mock.
]]
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local globals = require("./globals")

local ROOTS = {
	["ReplicatedStorage.Shared"] = "src/shared",
	["ServerScriptService.Server"] = "src/server",
	["StarterPlayer.StarterPlayerScripts.Client"] = "src/client",
}

local Loader = {}
Loader.__index = Loader

export type Loader = typeof(setmetatable(
	{} :: { overrides: { [string]: any }, services: { [string]: any }, cache: { [string]: any } },
	Loader
))

function Loader.new(): Loader
	return setmetatable({ overrides = {}, services = {}, cache = {} }, Loader)
end

-- Path proxy: indexing builds dotted instance paths
local PathMT = {}
local function path(loader, p: string)
	return setmetatable({ __path = p, __loader = loader }, PathMT)
end
PathMT.__index = function(self, key)
	if key == "GetService" then
		return function(_, name)
			local svc = rawget(self, "__loader").services[name]
			if svc ~= nil then
				return svc
			end
			return path(rawget(self, "__loader"), name)
		end
	end
	if key == "Parent" then
		local p = rawget(self, "__path")
		local parent = string.match(p, "^(.*)%.[^%.]+$")
		return path(rawget(self, "__loader"), parent or "")
	end
	local p = rawget(self, "__path")
	return path(rawget(self, "__loader"), if p == "" then key else p .. "." .. key)
end

local function toFile(p: string): string?
	for prefix, dir in ROOTS do
		if p == prefix or string.sub(p, 1, #prefix + 1) == prefix .. "." then
			local rest = string.sub(p, #prefix + 2)
			local base = dir .. (if rest == "" then "" else "/" .. string.gsub(rest, "%.", "/"))
			for _, cand in { base .. ".luau", base .. "/init.luau", base .. ".lua" } do
				if fs.isFile(cand) then
					return cand
				end
			end
		end
	end
	return nil
end

function Loader.mock(self: Loader, instancePath: string, value: any)
	self.overrides[instancePath] = value
end

function Loader.service(self: Loader, name: string, value: any)
	self.services[name] = value
end

function Loader.require(self: Loader, instancePath: string): any
	if self.overrides[instancePath] ~= nil then
		return self.overrides[instancePath]
	end
	if self.cache[instancePath] ~= nil then
		return self.cache[instancePath]
	end
	local file = toFile(instancePath)
	assert(file, "loader: cannot resolve " .. instancePath)
	local source = fs.readFile(file)
	local env = {
		game = path(self, ""),
		script = path(self, instancePath),
		require = function(target)
			if type(target) == "table" and rawget(target, "__path") then
				return self:require(rawget(target, "__path"))
			end
			return self.overrides[tostring(target)] or error("loader: bad require target")
		end,
	}
	for k, v in globals do
		env[k] = v
	end
	local fn = luau.load(source, { debugName = file, environment = env })
	local result = fn()
	self.cache[instancePath] = result
	return result
end

return Loader
