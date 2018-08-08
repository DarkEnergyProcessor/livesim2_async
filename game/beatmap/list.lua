-- Beatmap Lister
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

--[[
Beatmap lister lists beatmaps in separate thread using love.filesystem
and in asynchronous manner.

Beatmap lister returns these properties (all fields must exists unless noted):
{
	name = beatmap name,
	info = beatmap arrangement things (or nil),
	audio = audio file path (or FileData; can be nil),
	format = beatmap format name (readable),
	formatInternal = beatmap format (internal name),
	scoreS, scoreA, scoreB, scoreC = score meter (all nil or all available),
	comboS, comboA, comboB, comboC = combo meter (all nil or all available),
	difficulty = beatmap difficulty string (can in %dstar (%dstar random) but other are possible; can be nil),
	coverArt = cover art image path or FileData (or nil),
}

The order of the returned values are undefined, as all objects are also
processed (parsed) in another thread.

If the return is string, that means the beatmap is invalid, and it should
be printed to user console (debugging purpose)
]]

local love = require("love")
local beatmapList = {
	count = 0,
	thread = nil,
	channel = nil
}

function beatmapList.push()
	if beatmapList.count == 0 then
		beatmapList.thread = love.thread.newThread("game/beatmap/thread.lua")
		beatmapList.channel = love.thread.newChannel()
		beatmapList.thread:start(beatmapList.channel)
	end
	beatmapList.count = beatmapList.count + 1
end

function beatmapList.pop()
	assert(beatmapList.count > 0, "unable to pop")

	beatmapList.count = beatmapList.count - 1
	if beatmapList.count == 0 then
		beatmapList.channel:push("quit")
		beatmapList.channel = nil
		beatmapList.thread = nil
	end
end

function beatmapList.enumerate()
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.thread:push("enum")
end

return beatmapList
