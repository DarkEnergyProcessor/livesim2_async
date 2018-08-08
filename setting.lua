-- Configuration system (across threads)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
love._version = love._version or love.getVersion()
local setting = {}
local arg = ...

if type(arg) == "userdata" and arg:typeOf("Channel") then
	-- Secondary thread only
	require("love.filesystem") -- needed by our thread
	if jit and (love._os == "Android" or love._os == "iOS") then
		jit.off()
	end
	local channel = arg
	setting.list = {}
	setting.default = {}
	setting.modified = {}

	-- Get configuration
	local function getConfigImpl(key)
		key = key:upper()

		-- Cache
		if setting.list[key] then
			return setting.list[key]
		end
		-- livesim2 v2.x backward compatibility
		local file = love.filesystem.newFile(key..".txt")

		if not(file:open("r")) then
			file = love.filesystem.newFile("config/"..key..".txt")

			if not(file:open("r")) then
				assert(file:open("w"))
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
		setting.list[key] = val
		setting.modified[key] = true
	end

	local function commitConfigImpl()
		-- Call sparingly, expensive!
		for k in pairs(setting.modified) do
			assert(love.filesystem.write("config/"..k:upper()..".txt", tostring(setting.list[k])))
		end
	end

	local function isFileExist(path)
		if love._version >= "11.0" then
			return not(not(love.filesystem.getInfo(path, "file")))
		else
			return love.filesystem.isFile(path)
		end
	end

	local function processCommand(chan, command)
		if command == "init" then
			-- initialize new configuration
			local name = chan:demand():upper()
			local default = chan:demand()
			setting.default[name] = default

			if isFileExist(name..".txt") then
				-- old, backward compatible livesim2 config
				setting.list[name] = getConfigImpl(name)
				setting.modified[name] = true
				-- TODO: delete
			elseif not(isFileExist("config/"..name..".txt")) then
				setting.list[name] = default
				setting.modified[name] = true
			end
		elseif command == "def" then
			local name = chan:demand():upper()
			chan:push(setting.default[name])
		elseif command == "get" then
			local name = chan:demand()
			chan:push(getConfigImpl(name))
		elseif command == "set" then
			local name = chan:demand():upper()
			local value = chan:demand()
			setConfigImpl(name, value)
		elseif command == "commit" then
			commitConfigImpl()
		elseif command == "quit" then
			commitConfigImpl()
			return "quit"
		end
		return ""
	end

	while true do
		local command = channel:demand()
		if channel:performAtomic(processCommand, command) == "quit" then
			-- Done thread
			return
		end
	end
else
	-- Get named channel
	setting.channel = love.thread.getChannel("setting.lua")

	if setting.channel:getCount() == 0 then
		-- Main thread only
		assert(love.filesystem.createDirectory("config"), "failed to create configuration directory")
		setting.thread = assert(love.thread.newThread("setting.lua"))
		setting.channel:push(0) -- arbitrary value is okay
		setting.thread:start(setting.channel)
	end
end

----------------
-- Public API --
----------------

local function defineImpl(chan, key, default)
	chan:push("init")
	chan:push(key)
	chan:push(tostring(default))
end

function setting.define(key, default)
	assert(setting.thread, "'define' can only be called in main thread")
	return setting.channel:performAtomic(defineImpl, key, default)
end

local function defImpl(chan, key)
	chan:push("def")
	chan:push(key)
end

function setting.default(key)
	setting.channel:performAtomic(defImpl, key)
	return setting.channel:demand()
end

local function getImpl(chan, key)
	chan:push("get")
	chan:push(key)
end

function setting.get(key)
	setting.channel:performAtomic(getImpl, key)
	return setting.channel:demand()
end

local function setImpl(chan, key, value)
	chan:push("set")
	chan:push(key)
	chan:push(tostring(value))
end

function setting.set(key, value)
	return setting.channel:performAtomic(setImpl, key, value)
end

function setting.update()
	assert(setting.thread, "'update' can only be called in main thread")
	setting.channel:push("commit")
end

function setting.quit()
	assert(setting.thread, "'quit' can only be called in main thread")
	setting.channel:push("quit")
	setting.thread:wait()
end

return setting
