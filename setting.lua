-- Configuration system (across threads)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Util = require("util")

love._version = love._version or love.getVersion()

local Setting = {}
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
	Setting.list = {}
	Setting.default = {}
	Setting.modified = {}

	-- Get configuration
	local function getConfigImpl(key)
		key = key:upper()
		assert(Setting.default[key], "invalid setting name")

		-- Cache
		if Setting.list[key] then
			return Setting.list[key]
		end

		local file = Util.newFileCompat("config/"..key..".txt", "r")
		if not file then
			-- livesim2 v2.x backward compatibility
			file = Util.newFileCompat(key..".txt" ,"r")

			if not file then
				file = assert(Util.newFileCompat("config/"..key..".txt", "w"))
				file:write(assert(Setting.default[key]))
				file:close()

				return Setting.default[key]
			end
		end

		local data = file:read()
		file:close()

		return tonumber(data) or data
	end

	local function setConfigImpl(key, val)
		key = key:upper()
		assert(Setting.default[key], "invalid setting name")
		Setting.list[key] = val
		Setting.modified[key] = true
	end

	local function commitConfigImpl()
		-- Call sparingly, expensive!
		for k in pairs(Setting.modified) do
			love.filesystem.write("config/"..k:upper()..".txt", tostring(Setting.list[k]))
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
			Setting.default[name] = tonumber(default) or default

			if Util.fileExists(name..".txt") then
				-- old, backward compatible livesim2 config
				Setting.list[name] = getConfigImpl(name)
				Setting.modified[name] = true
				love.filesystem.remove(name..".txt")
			elseif not(Util.fileExists("config/"..name..".txt")) then
				Setting.list[name] = default
				Setting.modified[name] = true
			end
		elseif command == "def" then
			local name = channel:demand():upper()
			receiveChannel:push(Setting.default[name])
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
		collectgarbage()
		local command = channel:demand()
		if processCommand(command) == "quit" then
			-- Clean up channel
			while channel:getCount() > 0 do channel:pop() end
			-- Done thread
			return
		end
		collectgarbage()
		collectgarbage()
	end
else
	-- Get named channel
	Setting.channel = love.thread.getChannel("setting.lua")
	Setting.channelMain = love.thread.getChannel("setting.lua.lock")
	Setting.receiveChannel = love.thread.newChannel()

	if Setting.channelMain:getCount() == 0 then
		-- Main thread only
		assert(love.filesystem.createDirectory("config"), "failed to create configuration directory")
		Setting.thread = assert(love.thread.newThread("setting.lua"))
		Setting.channelMain:push(0) -- arbitrary value
		while Setting.channel:getCount() > 0 do Setting.channel:pop() end
		Setting.thread:start(Setting.channel)
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
	return Setting.channel:performAtomic(sendImpl, name, Setting.receiveChannel, ...)
end

function Setting.define(key, default)
	assert(Setting.thread, "'define' can only be called in main thread")
	return send("init", key, default)
end

function Setting.default(key)
	return send("def", key)
end

function Setting.get(key)
	send("get", key)

	local v = Setting.receiveChannel:demand()
	if v == Setting.receiveChannel then
		error(Setting.receiveChannel:demand(), 2)
	end
	return v
end

function Setting.set(key, value)
	return send("set", key, value)
end

function Setting.update()
	assert(Setting.thread, "'update' can only be called in main thread")
	return send("commit")
end

function Setting.quit()
	assert(Setting.thread, "'quit' can only be called in main thread")
	send("quit")
	if Setting.thread:isRunning() then
		Setting.thread:wait()
	end

	while Setting.channelMain:getCount() > 0 do Setting.channelMain:pop() end
end


return Setting
