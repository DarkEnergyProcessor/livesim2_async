-- Beatmap Lister
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

--[[
Beatmap lister lists beatmaps in separate thread using love.filesystem
and in asynchronous manner.

Beatmap lister returns these properties:
{
	name = beatmap name,
	info = beatmap arrangement things,
	audio = audio file (or FileData),
	format = beatmap format name (readable),
	formatInternal = beatmap format (internal name),
	scoreS, scoreA, scoreB, scoreC = score meter,
	comboS, comboA, comboB, comboC = combo meter,
	difficulty = beatmap difficulty string (can in %dstar (%dstar random) but other are possible)
}

The order of the returned values are undefined, as all objects are also
processed (parsed) in another thread.
]]

local love = require("love")
local async = require("async")
local beatmapList = {}

local function beatmapListReal(cb)
	local thread = love.thread.newThread("game/beatmap/listThread.lua")
	local outChan = love.thread.newChannel()
	thread:start(outChan, false)
end

function beatmapList.List(callback)
	local a = async.runFunction(beatmapListReal)
	a:run(callback)
end

return beatmapList
