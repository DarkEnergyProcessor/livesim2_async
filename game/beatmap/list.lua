-- Beatmap Lister
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

--[[
Beatmap lister lists beatmaps in separate thread using love.filesystem
and in asynchronous manner.

Beatmap lister returns these properties (all fields must exists unless noted):
{
	name = beatmap name,
	audio = audio file path (or FileData; can be nil),
	format = beatmap format name (readable),
	formatInternal = beatmap format (internal name),
	scoreS, scoreA, scoreB, scoreC = score meter (all nil or all available),
	comboS, comboA, comboB, comboC = combo meter (all nil or all available),
	difficulty = beatmap difficulty string (can in %dstar (%dstar random) but other are possible; can be nil),
	coverArt = cover art data ({title = title, image = imagedata, info = arr info}; can be nil),
}

The order of the returned values are undefined, as all objects are also
processed (parsed) in another thread.

If the return is string, that means the beatmap is invalid, and it should
be printed to user console (debugging purpose)

"beatmapresponse" is sent to LOVE event handler.
]]

local love = require("love")
local beatmapList = {
	count = 0,
	thread = nil,
	channel = nil,
	callback = {}
}

-- Request ID used to distinguish between different request
-- Copy from Lily
local function registerRequestID(callback)
	local t = {}
	for _ = 1, 64 do
		t[#t + 1] = string.char(math.random(0, 255))
	end

	local id = table.concat(t)
	beatmapList.callback[id] = callback
	return id
end

function love.handlers.beatmapresponse(name, id, data)
	if beatmapList.callback[id] then
		if name == "error" then
			beatmapList.callback[id] = nil
			error(data[1])
		elseif name == "enum" then
			local cb = beatmapList.callback[id]
			if data[1] == "" then
				beatmapList.callback[id] = nil
			end
			cb(unpack(data))
		else
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(unpack(data))
		end
	end
end

function beatmapList.push()
	if beatmapList.count == 0 then
		if beatmapList.thread then
			beatmapList.thread:wait()
		end
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
	end
end

function beatmapList.getSummary(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:push("summary")
	beatmapList.channel:push({registerRequestID(callback), name})
end

function beatmapList.enumerate(callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:push("enum")
	beatmapList.channel:push({registerRequestID(callback)})
end

return beatmapList
