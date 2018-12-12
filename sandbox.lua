-- Lua sandboxing
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Should I told you that sandbox is slow!!!

local Luaoop = require("libs.Luaoop")
local utf8 = require("utf8")
local util = require("util")
local sandbox = Luaoop.class("Livesim2.Sandbox")

function sandbox:__construct()
	local internal = Luaoop.class.data(self)

	-- Module sandboxing (blacklist method)
	local stringModule = util.deepCopy(string)
	stringModule.dump = nil

	-- Modules that is loaded
	internal.loadedModules = {
		coroutine = util.deepCopy(coroutine),
		math = util.deepCopy(math),
		os = {
			difftime = os.difftime,
			time = os.time,
			date = os.date,
			clock = os.clock
		},
		string = stringModule,
		table = util.deepCopy(table),
		utf8 = util.deepCopy(utf8),
	}
	if bit then
		internal.loadedModules.bit = util.deepCopy(bit)
	end

	-- Require function handlers
	-- Must return status (true if module loaded) plus module value
	internal.requireHandlers = {}

	-- Require function preloads
	internal.requirePreload = {}

	-- Metatable that shouldn't be returned
	internal.restrictedMetatable = {
		getmetatable("") -- string metatable
	}

	-- Setup Lua environment
	internal.env = {
		assert = assert,
		error = error,
		getmetatable = function(t)
			local v = getmetatable(t)
			for i = 1, #internal.restrictedMetatable do
				if internal.restrictedMetatable[i] == v then
					error("attempt to getmetatable of protected data")
				end
			end
			return v
		end,
		ipairs = ipairs,
		loadstring = function(f, name)
			local r, msg = loadstring(f, name)
			if r then
				setfenv(r, internal.env)
			end
			return r, msg
		end,
		next = next,
		pairs = pairs,
		pcall = pcall,
		print = print,
		rawget = rawget,
		rawset = rawset,
		rawequal = rawequal,
		require = function(name)
			if internal.loadedModules[name] then
				return internal.loadedModules[name]
			elseif internal.requirePreload[name] then
				local module = internal.requirePreload[name](name) or true
				internal.loadedModules[name] = module
				return module
			else
				-- call handlers
				for i = 1, #internal.requireHandlers do
					local status, module = internal.requireHandlers[i](name)
					if status then
						module = module or true
						internal.loadedModules[name] = module
						return module
					end
				end
				error("module '"..name.."' not found")
			end
		end,
		setmetatable = setmetatable,
		tonumber = tonumber,
		tostring = tostring,
		type = type,
		unpack = unpack,
		_VERSION = _VERSION,
		xpcall = xpcall,
	}
	internal.env._G = internal.env
	for k, v in pairs(internal.loadedModules) do
		internal.env[k] = v
	end
end

local _temporarySelf

local function _runWrap()
	return _temporarySelf.tempFunc(unpack(_temporarySelf.tempArg))
end

function sandbox:run(func, ...)
	local internal = Luaoop.class.data(self)
	setfenv(func, internal.env)
	self.tempFunc = func
	self.tempArg = {...}
	_temporarySelf = self
	local out = {xpcall(_runWrap, debug.traceback)}
	_temporarySelf = nil
	self.tempFunc = nil
	self.tempArg = nil
	return unpack(out)
end

function sandbox:restrictMetatable(meta)
	local internal = Luaoop.class.data(self)
	internal.restrictedMetatable[#internal.restrictedMetatable + 1] = meta
end

function sandbox:getEnv()
	return Luaoop.class.data(self).env
end

function sandbox:addModuleHandler(func)
	local internal = Luaoop.class.data(self)
	internal.requireHandlers[#internal.requireHandlers + 1] = func
end

function sandbox:preloadModule(name, func)
	local internal = Luaoop.class.data(self)
	internal.requirePreload[name] = func
end

return sandbox
