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
local PostExit = require("post_exit")
local BeatmapList = {
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
	BeatmapList.callback[id] = callback
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

function love.handlers.beatmapresponse(name, id, a, b, c, d, e)
	if name == "error" then
		BeatmapList.callback[id] = nil
		error(a)
	elseif BeatmapList.callback[id] then
		if name == "loaders" then
			local cb = BeatmapList.callback[id]
			if a == "" then
				BeatmapList.callback[id] = nil
			end
			if not(cb(a, b, c, d)) then
				BeatmapList.callback[id] = nil
			end
		elseif name == "enum" then
			local cb = BeatmapList.callback[id]
			c = c or {}
			if a == "" then
				BeatmapList.callback[id] = nil
			end
			if not(cb(a, b, c[2], d, c[1], e)) then
				BeatmapList.callback[id] = nil
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
			local cb = BeatmapList.callback[id]
			BeatmapList.callback[id] = nil
			cb(notes)
		elseif name == "unitinfo" then
			local cb = BeatmapList.callback[id]
			BeatmapList.callback[id] = nil
			cb(channelToTable(a))
		elseif name == "summary" then
			local cb = BeatmapList.callback[id]
			BeatmapList.callback[id] = nil
			cb(channelToTable(a))
		elseif name == "load" then
			local cb = BeatmapList.callback[id]
			BeatmapList.callback[id] = nil
			cb(a, channelToTable(b))
		elseif name == "story" then
			local cb = BeatmapList.callback[id]
			BeatmapList.callback[id] = nil

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
			local cb = BeatmapList.callback[id]
			BeatmapList.callback[id] = nil
			cb(a, b, c, d)
		end
	end
end

function BeatmapList.push()
	assert(BeatmapList.hasQuit == false, "beatmap list is already uninitialized")
	if BeatmapList.count == 0 then
		if BeatmapList.thread and BeatmapList.thread:isRunning() then
			BeatmapList.thread:wait()
		end
		BeatmapList.thread = love.thread.newThread("game/beatmap/thread.lua")
		BeatmapList.channel = love.thread.newChannel()
		BeatmapList.thread:start(BeatmapList.channel)
	end
	BeatmapList.count = BeatmapList.count + 1
end

local function sendData(chan, name, arg)
	chan:push(name)
	chan:push(arg)
end

function BeatmapList.pop(wait)
	if BeatmapList.hasQuit then return end
	assert(BeatmapList.count > 0, "unable to pop")

	BeatmapList.count = BeatmapList.count - 1
	if BeatmapList.count == 0 then
		BeatmapList.channel:performAtomic(sendData, "quit", {})
		BeatmapList.channel = nil

		if wait then
			BeatmapList.thread:wait()
		end
	end
end

-- callback: summary
function BeatmapList.getSummary(name, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "summary", {registerRequestID(callback), name})
end

-- callback: notesList channel
function BeatmapList.getNotes(name, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "notes", {registerRequestID(callback), name})
end

-- callback: backgrounds channel
function BeatmapList.getBackground(name, video, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "background", {registerRequestID(callback), name, video})
end

-- callback: unit list channel
function BeatmapList.getCustomUnit(name, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "unitinfo", {registerRequestID(callback), name})
end

function BeatmapList.getStoryboard(name, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "story", {registerRequestID(callback), name})
end

function BeatmapList.getCoverArt(name, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "cover", {registerRequestID(callback), name})
end

function BeatmapList.enumerate(callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "enum", {registerRequestID(callback)})
end

function BeatmapList.enumerateLoaders(callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "loaders", {registerRequestID(callback)})
end

-- callback: id (may print unprintable char), summary
function BeatmapList.registerAbsolute(path, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "load", {registerRequestID(callback), path})
end

function BeatmapList.registerRelative(path, callback)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "loadrel", {registerRequestID(callback), path})
end

-- For grouped beatmap, all difficulty will be deleted!
function BeatmapList.deleteBeatmap(name)
	assert(BeatmapList.count > 0, "beatmap list not initialized")
	BeatmapList.channel:performAtomic(sendData, "rm", {registerRequestID(), name})
end

function BeatmapList.isActive()
	return BeatmapList.count > 0
end

PostExit.add(function()
	if BeatmapList.count > 0 then
		BeatmapList.channel:performAtomic(sendData, "quit", {})
		if BeatmapList.thread and BeatmapList.thread:isRunning() then
			BeatmapList.thread:wait()
		end
		BeatmapList.count = 0
	elseif BeatmapList.thread and BeatmapList.thread:isRunning() then
		BeatmapList.thread:wait()
	end

	BeatmapList.thread = nil
	BeatmapList.channel = nil
	BeatmapList.hasQuit = true
end)

return BeatmapList
