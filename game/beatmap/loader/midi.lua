-- MIDI Beatmap Loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local bit = require("bit")
local Luaoop = require("libs.Luaoop")
local md5 = require("md5")
local baseLoader = require("game.beatmap.base")

local function str2dwordBE(str)
	local a, b, c, d = str:sub(1, 4):byte(1, 4)
	return a * 16777216 + b * 65536 + c * 256 + d
end

local function readVarint(fs)
	local last_bit_set
	local read = 0
	local out = 0

	repeat
		local b = tonumber(fs:read(1):byte())
		read = read + 1

		last_bit_set = bit.band(b, 128) > 0
		out = out * 128 + (b % 128)
	until last_bit_set == false

	return tonumber(out), read
end

local function midi2sif(stream)
	assert(stream:read(4) == "MThd", "Not MIDI")
	assert(str2dwordBE(stream:read(4)) == 6, "Header size not 6")
	stream:read(2)

	local ntrkCount = str2dwordBE("\0\0"..stream:read(2))
	local ppqn = str2dwordBE("\0\0"..stream:read(2))

	local tempo = 120			-- Default tempo, 120 BPM
	local eventList = {}		-- Will be analyzed later. For now, just collect all of it

	assert(ppqn < 32768, "PPQN is negative")

	local function insertEvent(tick, data)
		if eventList[tick] then
			table.insert(eventList[tick], data)
		else
			eventList[tick] = {data}
		end
	end

	for _ = 1, ntrkCount do
		assert(stream:read(4) == "MTrk", "Not MIDI Track")

		local mtrkLen = str2dwordBE(stream:read(4))
		local readed = 0
		local timingTotal = 0

		while readed < mtrkLen do
			local timing, read = readVarint(stream)
			local event_byte = stream:read(1):byte()
			local event_type = math.floor(event_byte / 16)
			local note, velocity
			readed = readed + read + 1
			timingTotal = timingTotal + timing

			if event_type == 8 then
				-- Note Off
				note = stream:read(1):byte()
				velocity = stream:read(1):byte()
				readed = readed + 2

				insertEvent(timingTotal, {
					note = false,	-- false = off, true = on.
					pos = note,
					velocity = velocity,
					channel = event_byte % 16
				})
			elseif event_type == 9 then
				-- Note On
				note = stream:read(1):byte()
				velocity = stream:read(1):byte()
				readed = readed + 2

				insertEvent(timingTotal, {
					note = true,	-- false = off, true = on.
					pos = note,
					velocity = velocity,
					channel = event_byte % 16
				})
			elseif event_type == 12 or event_type == 13 then
				-- Program change or Aftertouch
				stream:read(1)
				readed = readed + 1
			elseif event_byte == 255 then
				-- meta
				local meta, len
				meta = stream:read(1):byte()
				len, read = readVarint(stream)
				insertEvent(timingTotal, {
					meta = meta,
					data = stream:read(len)
				})
				readed = readed + 1 + read + len
			elseif event_byte == 240 or event_byte == 247 then
				-- sysex event
				while stream:read(1):byte() ~= 247 do
					readed = readed + 1
				end
				readed = readed + 1
			else
				stream:read(2)
				readed = readed + 2
			end
		end
	end

	-- Now, create new event_list table
	local temp_event_list = eventList
	eventList = {}

	for n, v in pairs(temp_event_list) do
		for a, b in ipairs(v) do
			table.insert(eventList, {
				tick = n,
				order = a,
				meta = b.meta,
				data = b.data,
				note = b.note,
				pos = b.pos,
				vel = b.velocity,
				channel = b.channel
			})
		end
	end

	-- Sort by tick, then by order. All are ascending
	table.sort(eventList, function(a, b)
		return a.tick < b.tick or (a.tick == b.tick and a.order < b.order)
	end)

	local top_index = 0
	local bottom_index = 127

	-- Analyze start and end position.
	for _, v in ipairs(eventList) do
		if type(v.note) == "boolean" then
			-- Note
			top_index = math.max(top_index, v.pos)
			bottom_index = math.min(bottom_index, v.pos)
		end
	end

	local mid_idx = top_index - bottom_index  + 1
	assert(
		mid_idx <= 9 and mid_idx % 2 == 1,
		"failed to analyze note position, make sure to only use 9 note keys or odd amount of note keys"
	)

	-- If it's not 9 and it's odd, automatically adjust
	if mid_idx ~= 9 and mid_idx % 2 == 1 then
		local mid_pos = (top_index + bottom_index) / 2

		--top_index = mid_pos + 4
		bottom_index = mid_pos - 4
	end

	-- Now start conversion.
	local longnote_queue = {}
	local sif_beatmap = {}
	local last_timing_sec = 0
	local last_tick = 0

	for _, v in ipairs(eventList) do
		if v.meta == 81 then
			-- Tempo change
			local tempo_num = {string.byte(v.data, 1, 128)}
			last_timing_sec = v.tick * 60 / ppqn / tempo
			last_tick = v.tick
			tempo = 0

			for i = 1, #tempo_num do
				tempo = tempo * 256 + tempo_num[i]
			end

			tempo = math.floor((60000000000 / tempo) + 0.5) / 1000
		elseif type(v.note) == "boolean" then
			local position = v.pos - bottom_index + 1
			local attribute = math.floor(v.channel / 4)
			local effect = v.channel % 4 + 1
			local is_swing = v.vel < 64

			if attribute > 0 then
				if v.note then
					if effect == 3 then
						-- Add to longnote queue
						assert(longnote_queue[position] == nil, "another note in pos "..position.." is in queue")
						longnote_queue[position] = {v.tick, attribute, effect, position, v.vel}
					else
						sif_beatmap[#sif_beatmap + 1] = {
							timing_sec = (v.tick - last_tick) * 60 / ppqn / tempo + last_timing_sec,
							notes_attribute = attribute,
							notes_level = is_swing and v.vel + 1 or 1,
							effect = effect + (is_swing and 10 or 0),
							effect_value = 2,
							position = position
						}
					end
				elseif v.note == false and effect == 3 then
					-- Stop longnote queue
					local queue = longnote_queue[position]
					if not(queue) then
						error("queue for pos "..position.." is empty")
					end

					is_swing = queue[5] < 64

					longnote_queue[position] = nil
					sif_beatmap[#sif_beatmap + 1] = {
						timing_sec = (queue[1] - last_tick) * 60 / ppqn / tempo + last_timing_sec,
						notes_attribute = attribute,
						notes_level = is_swing and queue[5] + 1 or 1,
						effect = is_swing and 13 or 3,
						effect_value = (v.tick - queue[1]) * 60 / ppqn / tempo,
						position = position
					}
				end
			end
		end
	end

	table.sort(sif_beatmap, function(a, b) return a.timing_sec < b.timing_sec end)

	return sif_beatmap
end

-------------------------
-- MIDI Beatmap Loader --
-------------------------

local midiLoader = Luaoop.class("beatmap.MIDI", baseLoader)

function midiLoader:__construct(file)
	local internal = Luaoop.class.data(self)
	internal.hash = md5(love.filesystem.newFileData(file))
	file:seek(0)
	internal.data = midi2sif(file)
end

function midiLoader.getFormatName()
	return "MIDI Beatmap", "midi"
end

function midiLoader:getHash()
	return Luaoop.class.data(self).hash
end

function midiLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	return internal.data
end

return midiLoader, "file"
