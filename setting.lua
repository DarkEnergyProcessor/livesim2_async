-- Configuration system (across threads)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local util = require("util")

love._version = love._version or love.getVersion()

local setting = {}
local arg = ...

if type(arg) == "userdata" and arg:typeOf("Channel") then
	-- Secondary thread only
	require("love.filesystem") -- needed by our thread
	require("love.timer")
	if jit and (love._os == "Android" or love._os == "iOS") then
		jit.off()
	end
	require("util")
	local log = require("logging")
	local channel = arg
	setting.list = {}
	setting.default = {}
	setting.modified = {}

	-- Get configuration
	local function getConfigImpl(key)
		key = key:upper()
		assert(setting.default[key], "invalid setting name")

		-- Cache
		if setting.list[key] then
			return setting.list[key]
		end

		local file = util.newFileCompat("config/"..key..".txt", "r")
		if not file then
			-- livesim2 v2.x backward compatibility
			file = util.newFileCompat(key..".txt" ,"r")

			if not file then
				file = assert(util.newFileCompat("config/"..key..".txt", "w"))
				file:write(assert(setting.default[key]))
				file:close()

				return setting.default[key]
			end
		end

		local data = file:read()
		file:close()

		return tonumber(data) or data
	end

	local function setConfigImpl(key, val)
		key = key:upper()
		assert(setting.default[key], "invalid setting name")
		setting.list[key] = val
		setting.modified[key] = true
	end

	local function commitConfigImpl()
		-- Call sparingly, expensive!
		for k in pairs(setting.modified) do
			love.filesystem.write("config/"..k:upper()..".txt", tostring(setting.list[k]))
		end
	end

	local function processCommand(command)
		if command == "quit" then
			commitConfigImpl()
			return "quit"
		end
		local receiveChannel = channel:demand()
		if command == "init" then
			-- initialize new configuration
			local name = channel:demand():upper()
			local default = channel:demand()
			setting.default[name] = tonumber(default) or default

			if util.fileExists(name..".txt") then
				-- old, backward compatible livesim2 config
				setting.list[name] = getConfigImpl(name)
				setting.modified[name] = true
				love.filesystem.remove(name..".txt")
			elseif not(util.fileExists("config/"..name..".txt")) then
				setting.list[name] = default
				setting.modified[name] = true
			end
		elseif command == "def" then
			local name = channel:demand():upper()
			receiveChannel:push(setting.default[name])
		elseif command == "get" then
			local name = channel:demand()
			local s, value = pcall(getConfigImpl, name)
			log.debugf("setting", "get: %s, value: %s", name, tostring(value))
			if s then
				receiveChannel:push(value)
			else
				receiveChannel:push(receiveChannel)
				receiveChannel:push(value:sub((select(2, value:find(":%d+:")) or 1)+2))
			end
		elseif command == "set" then
			local name = channel:demand():upper()
			local value = channel:demand()
			log.debugf("setting", "set: %s, value: %s", name, tostring(value))
			pcall(setConfigImpl, name, value)
		elseif command == "commit" then
			commitConfigImpl()
		end
		return ""
	end

	while true do
		collectgarbage()
		local command = channel:demand()
		if processCommand(command) == "quit" then
			-- Clean up channel
			while channel:getCount() > 0 do channel:pop() end
			-- Done thread
			return
		end
	end
else
	-- Get named channel
	setting.channel = love.thread.getChannel("setting.lua")
	setting.channelMain = love.thread.getChannel("setting.lua.lock")
	setting.receiveChannel = love.thread.newChannel()

	if setting.channelMain:getCount() == 0 then
		-- Main thread only
		assert(love.filesystem.createDirectory("config"), "failed to create configuration directory")
		setting.thread = assert(love.thread.newThread("setting.lua"))
		setting.channelMain:push(0) -- arbitrary value
		while setting.channel:getCount() > 0 do setting.channel:pop() end
		setting.thread:start(setting.channel)
	end
end

----------------
-- Public API --
----------------

local function sendImpl(chan, name, ...)
	chan:push(name)
	for i = 1, select("#", ...) do
		chan:push((select(i, ...)))
	end
end

local function send(name, ...)
	--return setting.channel:push({name, setting.receiveChannel, ...})
	return setting.channel:performAtomic(sendImpl, name, setting.receiveChannel, ...)
end

function setting.define(key, default)
	assert(setting.thread, "'define' can only be called in main thread")
	return send("init", key, default)
end

function setting.default(key)
	return send("def", key)
end

function setting.get(key)
	send("get", key)

	local v = setting.receiveChannel:demand()
	if v == setting.receiveChannel then
		error(setting.receiveChannel:demand(), 2)
	end
	return v
end

function setting.set(key, value)
	return send("set", key, value)
end

function setting.update()
	assert(setting.thread, "'update' can only be called in main thread")
	return send("commit")
end

function setting.quit()
	assert(setting.thread, "'quit' can only be called in main thread")
	send("quit")
	if setting.thread:isRunning() then
		setting.thread:wait()
	end

	while setting.channelMain:getCount() > 0 do setting.channelMain:pop() end
end


return setting
