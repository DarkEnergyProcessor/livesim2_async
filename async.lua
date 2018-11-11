-- Asynchronous operation wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Async operation requires it to run in coroutine
-- All operation return values that it's compatible
-- with assert(...) statement (values, or nil+error message)

local coroutine = require("coroutine")
local Luaoop = require("libs.Luaoop")
local lily = require("libs.lily")

local async = {
	events = {},
	backEvents = {},
}

local function asyncFunc(func)
	return function(...)
		if coroutine.running() == nil then
			return nil, "Async cannot function in main thread"
		end
		return func(...)
	end
end

-----------------------------
-- Base async object class --
-----------------------------
local asyncObject = Luaoop.class("async.Base")

function asyncObject.__construct()
	error("attempt to construct abstract class 'async.base'", 2)
end

function asyncObject.sync()
	error("attempt to call abstract method 'sync'", 2)
end

-------------------------------------
-- Lily wrapper async object class --
-------------------------------------
local wrapLilyClass = Luaoop.class("async.Lily", asyncObject)

function wrapLilyClass:__construct(lobj)
	self.lily = lobj
end

function wrapLilyClass:isComplete()
	return self.lily:isComplete()
end

function wrapLilyClass:sync()
	if coroutine.running() == nil then
		return nil, "Async cannot function in main thread"
	end

	while self.lily:isComplete() == false do
		async.wait()
	end
end

function wrapLilyClass:getValues()
	self:sync()
	return self.lily:getValues()
end

function wrapLilyClass:getLily()
	return self.lily
end

--------------------------
-- Function async class --
--------------------------

local funcAsync = Luaoop.class("async.Function", asyncObject)

function funcAsync:__construct(func)
	self.func = func
	self.coro = coroutine.create(func)
	self.running = false
end

function funcAsync:run(...)
	assert(self.running == false, "attempt to run already running function")
	local status, msg = coroutine.resume(self.coro, ...)
	if status == false then
		error(debug.traceback(self.coro, msg), 0)
	end
	self.running = true
end

function funcAsync:sync()
	local status = coroutine.status(self.coro)
	while status ~= "dead" do
		async.wait()
		status = coroutine.status(self.coro)
	end

	self.coro = coroutine.create(self.func)
	self.running = false
end

---------------------
-- Async functions --
---------------------

--- Sends control back to async scheduler
-- @param dt Time to wait
-- @return Time since the last update in seconds, or none if dt is specified.
function async.wait(dt) end
async.wait = asyncFunc(function(dt)
	if dt and dt > 0 then
		while dt > 0 do
			dt = dt - async.wait()
		end
	else
		local a = coroutine.running()
		if a == nil then
			error("async cannot function in main thread", 2)
		end
		async.events[#async.events + 1] = a
		return coroutine.yield()
	end
end)

-- luacheck: no unused args
--- Calls pending asynchronous task.
-- @param dt Time since the last update in seconds.
function async.loop(dt)
	async.backEvents, async.events = async.events, async.backEvents
	for i = #async.backEvents, 1, -1 do
		local coro = table.remove(async.backEvents, i)
		local status, err = coroutine.resume(coro, dt)
		if status == false then
			error(debug.traceback(coro, err), 0)
		end
	end
end

---------------------
-- Object creation --
---------------------

--- Load image in asynchronous way.
-- @param path Path to image.
-- @tparam table settings Image loading settings, as per love.graphics.newImage
-- @treturn WrapLilyClass Asynchronous object (Lily wrapper)
function async.loadImage(path, settings)
	return wrapLilyClass(lily.newImage(path, settings))
end

--- Load font in asynchronous way.
-- @tparam string path Path to font.
-- @tparam number size Font size.
-- @treturn WrapLilyClass Asynchronous object (Lily wrapper)
function async.loadFont(path, size)
	return wrapLilyClass(lily.newFont(path, size))
end

--- Load data with Lily
function async.syncLily(lobj)
	return wrapLilyClass(lobj)
end

--- Run function as asynchronous task.
-- You can call async.wait() inside the function
-- @tparam function func The function to run.
-- @treturn FunctionAsync object (call `:run(arg)` to run it)
function async.runFunction(func)
	return funcAsync(func)
end

return async
