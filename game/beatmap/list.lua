-- Beatmap Lister
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

--[[
Beatmap lister lists beatmaps in separate thread using love.filesystem
and in asynchronous manner.

Beatmap list returns these summary data (all fields must exists unless noted):
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

"beatmapresponse" is sent to LOVE event handler.
]]

local love = require("love")
local postExit = require("post_exit")
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

function love.handlers.beatmapresponse(name, id, a, b, c, d, e)
	if beatmapList.callback[id] then
		if name == "error" then
			beatmapList.callback[id] = nil
			error(a)
		elseif name == "enum" then
			local cb = beatmapList.callback[id]
			if a == "" then
				beatmapList.callback[id] = nil
			end
			if not(cb(a, b, c, d, e)) then
				beatmapList.callback[id] = nil
			end
		elseif name == "unitinfo" then
			local data = {}
			while a:getCount() > 0 do
				local k = a:pop()
				data[k] = a:pop()
			end

			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(data)
		else
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(a, b, c, d, e)
		end
	end
end

function beatmapList.push()
	if beatmapList.count == 0 then
		if beatmapList.thread and beatmapList.thread:isRunning() then
			beatmapList.thread:wait()
		end
		beatmapList.thread = love.thread.newThread("game/beatmap/thread.lua")
		beatmapList.channel = love.thread.newChannel()
		beatmapList.thread:start(beatmapList.channel)
	end
	beatmapList.count = beatmapList.count + 1
end

local function sendData(chan, name, arg)
	chan:push(name)
	chan:push(arg)
end

function beatmapList.pop()
	assert(beatmapList.count > 0, "unable to pop")

	beatmapList.count = beatmapList.count - 1
	if beatmapList.count == 0 then
		beatmapList.channel:performAtomic(sendData, "quit", {})
		beatmapList.channel = nil
	end
end

function beatmapList.getSummary(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "summary", {registerRequestID(callback), name})
end

function beatmapList.getNotes(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "notes", {registerRequestID(callback), name})
end

function beatmapList.getBackground(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "background", {registerRequestID(callback), name})
end

function beatmapList.getCustomUnit(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "unitinfo", {registerRequestID(callback), name})
end

function beatmapList.enumerate(callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "enum", {registerRequestID(callback)})
end

postExit.add(function()
	if beatmapList.count > 0 then
		beatmapList.channel:performAtomic(sendData, "quit", {})
		beatmapList.channel = nil
		if beatmapList.thread and beatmapList.thread:isRunning() then
			beatmapList.thread:wait()
			beatmapList.thread = nil
		end
		beatmapList.count = 0
	elseif beatmapList.thread and beatmapList.thread:isRunning() then
		beatmapList.thread:wait()
	end
end)

return beatmapList
