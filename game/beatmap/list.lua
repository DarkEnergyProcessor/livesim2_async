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
	hash = beatmap MD5 hash,
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
	hasQuit = false,
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

local function channelToTable(a)
	local data = {}
	while a:getCount() > 0 do
		local k = a:pop()
		data[k] = a:pop()
	end

	return data
end

function love.handlers.beatmapresponse(name, id, a, b, c, d)
	if beatmapList.callback[id] then
		if name == "error" then
			beatmapList.callback[id] = nil
			error(a)
		elseif name == "loaders" then
			local cb = beatmapList.callback[id]
			if a == "" then
				beatmapList.callback[id] = nil
			end
			if not(cb(a, b, c, d)) then
				beatmapList.callback[id] = nil
			end
		elseif name == "enum" then
			local cb = beatmapList.callback[id]
			c = c or {}
			if a == "" then
				beatmapList.callback[id] = nil
			end
			if not(cb(a, b, c[2], d, c[1])) then
				beatmapList.callback[id] = nil
			end
		elseif name == "notes" then
			local notes = {}
			local amount = a:pop()
			for _ = 1, amount do
				local t = {}
				while a:peek() ~= a do
					local k = a:pop()
					t[k] = a:pop()
				end

				-- pop separator
				a:pop()
				notes[#notes + 1] = t
			end
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(notes)
		elseif name == "unitinfo" then
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(channelToTable(a))
		elseif name == "summary" then
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(channelToTable(a))
		elseif name == "load" then
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(a, channelToTable(b))
		elseif name == "story" then
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil

			if a then
				local type = a:pop()
				local storyboard = a:pop()
				local path, data

				if a:pop() then
					path = a:pop()
				end

				if a:pop() then
					data = a:pop()
				end

				if data then
					local dataTable = {}
					while data:getCount() > 0 do
						dataTable[#dataTable + 1] = data:pop()
					end
					data = dataTable
				end

				cb({
					type = type,
					storyboard = storyboard,
					path = path,
					data = data
				})
			else
				cb(nil)
			end
		else
			local cb = beatmapList.callback[id]
			beatmapList.callback[id] = nil
			cb(a, b, c, d)
		end
	end
end

function beatmapList.push()
	assert(beatmapList.hasQuit == false, "beatmap list is already uninitialized")
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

function beatmapList.pop(wait)
	if beatmapList.hasQuit then return end
	assert(beatmapList.count > 0, "unable to pop")

	beatmapList.count = beatmapList.count - 1
	if beatmapList.count == 0 then
		beatmapList.channel:performAtomic(sendData, "quit", {})
		beatmapList.channel = nil

		if wait then
			beatmapList.thread:wait()
		end
	end
end

-- callback: summary
function beatmapList.getSummary(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "summary", {registerRequestID(callback), name})
end

-- callback: notesList channel
function beatmapList.getNotes(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "notes", {registerRequestID(callback), name})
end

-- callback: backgrounds channel
function beatmapList.getBackground(name, video, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "background", {registerRequestID(callback), name, video})
end

-- callback: unit list channel
function beatmapList.getCustomUnit(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "unitinfo", {registerRequestID(callback), name})
end

function beatmapList.enumerate(callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "enum", {registerRequestID(callback)})
end

function beatmapList.enumerateLoaders(callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "loaders", {registerRequestID(callback)})
end

function beatmapList.getStoryboard(name, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "story", {registerRequestID(callback), name})
end

-- callback: id (may print unprintable char), summary
function beatmapList.registerAbsolute(path, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "load", {registerRequestID(callback), path})
end

function beatmapList.registerRelative(path, callback)
	assert(beatmapList.count > 0, "beatmap list not initialized")
	beatmapList.channel:performAtomic(sendData, "loadrel", {registerRequestID(callback), path})
end

postExit.add(function()
	if beatmapList.count > 0 then
		beatmapList.channel:performAtomic(sendData, "quit", {})
		if beatmapList.thread and beatmapList.thread:isRunning() then
			beatmapList.thread:wait()
		end
		beatmapList.count = 0
	elseif beatmapList.thread and beatmapList.thread:isRunning() then
		beatmapList.thread:wait()
	end

	beatmapList.thread = nil
	beatmapList.channel = nil
	beatmapList.hasQuit = true
end)

return beatmapList
