-- Asynchronous operation wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Async operation requires it to run in coroutine
-- All operation return values that it's compatible
-- with assert(...) statement (values, or nil+error message)

local coroutine = require("coroutine")
local Luaoop = require("libs.Luaoop")
local lily = require("lily")

local Async = {
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
local AsyncObject = Luaoop.class("async.Base")

function AsyncObject.__construct()
	error("attempt to construct abstract class 'async.base'", 2)
end

function AsyncObject.sync()
	error("attempt to call abstract method 'sync'", 2)
end

-------------------------------------
-- Lily wrapper async object class --
-------------------------------------
local LilyWrapperAsync = Luaoop.class("async.Lily", AsyncObject)

function LilyWrapperAsync:__construct(lobj)
	self.lily = lobj
end

function LilyWrapperAsync:isComplete()
	return self.lily:isComplete()
end

function LilyWrapperAsync:sync()
	if coroutine.running() == nil then
		return nil, "Async cannot function in main thread"
	end

	while self.lily:isComplete() == false do
		Async.wait()
	end
end

function LilyWrapperAsync:getValues()
	self:sync()
	return self.lily:getValues()
end

function LilyWrapperAsync:getLily()
	return self.lily
end

--------------------------
-- Function async class --
--------------------------

local FuncAsync = Luaoop.class("async.Function", AsyncObject)

function FuncAsync:__construct(func)
	self.func = func
	self.coro = coroutine.create(func)
	self.running = false
end

function FuncAsync:run(...)
	assert(self.running == false, "attempt to run already running function")
	local status, msg = coroutine.resume(self.coro, ...)
	if status == false then
		error(debug.traceback(self.coro, msg), 0)
	end
	self.running = true
end

function FuncAsync:sync()
	local status = coroutine.status(self.coro)
	while status ~= "dead" do
		Async.wait()
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
function Async.wait(dt) end
Async.wait = asyncFunc(function(dt)
	if dt and dt > 0 then
		while dt > 0 do
			dt = dt - Async.wait()
		end
	else
		local a = coroutine.running()
		if a == nil then
			error("async cannot function in main thread", 2)
		end
		Async.events[#Async.events + 1] = a
		return coroutine.yield()
	end
end)

-- luacheck: no unused args
--- Calls pending asynchronous task.
-- @param dt Time since the last update in seconds.
function Async.loop(dt)
	Async.backEvents, Async.events = Async.events, Async.backEvents
	for i = #Async.backEvents, 1, -1 do
		local coro = table.remove(Async.backEvents, i)
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
-- @tparam function errhand Error handler of the object
-- @treturn WrapLilyClass Asynchronous object (Lily wrapper)
function Async.loadImage(path, settings, errhand)
	local l = lily.newImage(path, settings)
	if errhand then
		l:setUserData(path):onError(errhand)
	end

	return LilyWrapperAsync(l)
end

--- Load font in asynchronous way.
-- @tparam string path Path to font.
-- @tparam number size Font size.
-- @tparam number hinting For TTF fonts, type hinting of the font.
-- @tparam number dpiscale For LOVE 11.0 and later, DPI scale of the font.
-- @treturn WrapLilyClass Asynchronous object (Lily wrapper)
function Async.loadFont(path, size, hinting, dpiscale)
	return LilyWrapperAsync(lily.newFont(path, size, hinting, dpiscale))
end

--- Load data with Lily
function Async.syncLily(lobj)
	return LilyWrapperAsync(lobj)
end

--- Run function as asynchronous task.
-- You can call async.wait() inside the function
-- @tparam function func The function to run.
-- @treturn FunctionAsync object (call `:run(arg)` to run it)
function Async.runFunction(func)
	return FuncAsync(func)
end

return Async
