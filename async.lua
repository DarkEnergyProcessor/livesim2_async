-- Asynchronous operation wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Async operation requires it to run in coroutine
-- All operation return values that it's compatible
-- with assert(...) statement (values, or nil+error message)

local coroutine = require("coroutine")
local Luaoop = require("libs.Luaoop")
local lily = require("libs.lily")

local async = setmetatable({
	events = {},
	backEvents = {},
}, {
	__newindex = function(async, var, val)
		if type(val) == "function" then
			local oldval = val
			val = function(...)
				if coroutine.running() == nil then
					return nil, "Async cannot function in main thread"
				end
				return oldval(...)
			end
		end

		return rawset(async, var, val)
	end
})

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

function funcAsync:run(arg)
	assert(self.running == false, "attempt to run already running function")
	coroutine.resume(self.coro, arg)
	self.running = true
end

function funcAsync:sync()
	local status = coroutine.status(self.func)
	while status ~= "dead" do
		async.wait()
		status = coroutine.status(self.func)
	end

	self.coro = coroutine.create(self.func)
	self.running = false
end

---------------------
-- Async functions --
---------------------

function async.wait(...)
	if select("#", ...) > 0 then
		local dt = select(1, ...)
		while dt > 0 do
			dt = dt - async.wait()
		end
	else
		local a = coroutine.running()
		if a == nil then
			print("nil coro", debug.traceback())
			return nil, "Async cannot function in main thread"
		end
		async.events[#async.events + 1] = a
		return coroutine.yield()
	end
end

-- Must be set with rawset.
function async.loop(dt) end -- tricking LCA
rawset(async, "loop", function(dt)
	async.backEvents, async.events = async.events, async.backEvents
	for i = #async.backEvents, 1, -1 do
		local coro = table.remove(async.backEvents, i)
		local status, err = coroutine.resume(coro, dt)
		if status == false then
			error(err)
		end
	end
end)

---------------------
-- Object creation --
---------------------

function async.loadImage(path, settings)
	return wrapLilyClass(lily.newImage(path, settings))
end

function async.loadFont(path, size)
	return wrapLilyClass(lily.newFont(path, size))
end

function async.runFunction(func)
	return funcAsync(func)
end

return async
