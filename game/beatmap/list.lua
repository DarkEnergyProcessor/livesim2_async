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
local async = require("async")
local beatmapList = {
	threadRunning = false
}

local function beatmapListReal(cb)
	local thread = love.thread.newThread("game/beatmap/listThread.lua")
	local outChan = love.thread.newChannel()
	beatmapList.threadRunning = true
	thread:start(outChan, false)

	while thread:isRunning() do
		local count = 0


		while outChan:getCount() > 0 do
			if beatmapList.threadRunning == false then
				outChan:push(false) -- end thread
				break
			end

			local value = outChan:pop()
			if value then cb(value) end

			count = count + 1
			if count >= 5 then
				async.wait()
				count = 0
			end
		end

		if beatmapList.threadRunning == false then
			outChan:push(false) -- end thread
			break
		end

		async.wait()
	end

	-- On done, call cb with nil
	-- It doesn't differentiate between "cancel" and "done"
	beatmapList.threadRunning = false
	cb(nil)
end

function beatmapList.list(callback)
	assert(beatmapList.threadRunning == false, "another enumeration is in progress")
	local a = async.runFunction(beatmapListReal)
	a:run(callback)
end

function beatmapList.cancel()
	if beatmapList.threadRunning then
		beatmapList.threadRunning = false
	end
end

return beatmapList
