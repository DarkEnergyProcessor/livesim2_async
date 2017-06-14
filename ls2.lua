-- Live Simulator: 2 binary beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local ls2 = {
	_VERSION = "1.2",
	_LICENSE = "Copyright \169 2038 Dark Energy Processor, licensed under MIT/Expat. See copyright notice in main.lua",
	_AUTHOR  = "AuahDark",
	encoder = {}
}
local bit = require("bit")
local love = require("love")
local LuaStoryboard = require("luastoryboard2")

-- String to little endian dword (signed)
local function string2dword(str)
	return bit.bor(
		str:byte(),
		bit.lshift(str:sub(2,2):byte(), 8),
		bit.lshift(str:sub(3,3):byte(), 16),
		bit.lshift(str:sub(4,4):byte(), 24)
	)
end

-- String to little endian dword (unsigned)
local function string2dwordu(str)
	return string2dword(str) % 4294967296
end

-- String to little endian word (unsigned)
local function string2wordu(str)
	return bit.bor(str:byte(), bit.lshift(str:sub(2,2):byte(), 8))
end

-- String to little endian word (signed)
local function string2word(str)
	local x = string2dwordu(str)
	
	return x > 32767 and x - 65536 or x
end


-- String read datatype
local function readstring(stream)
	return stream:read(string2dwordu(stream:read(4)))
end

-- Generate random string
local function randstring(len)
	local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz"
	local list = {}
	
	for i = 1, len do
		local idx = math.random(1, #chars)
		
		list[i] = chars:sub(idx, idx)
	end
	
	return table.concat(list)
end

--------------------------------------------
-- Section processors functions (decoder) --
--------------------------------------------

--! @brief Beatmap Millisecond parser
--! @param stream The file stream
--! @returns SIF-compilant beatmap
local function process_BMPM(stream)
	local sif_notes = {}
	local amount_notes = string2dwordu(stream:read(4))
	
	for i = 1, amount_notes do
		local effect_new = 1
		local effect_new_val = 2
		local timing_sec = string2dwordu(stream:read(4)) / 1000
		local attribute = string2dwordu(stream:read(4))
		local note_effect = string2dwordu(stream:read(4))
		local position = bit.band(note_effect, 15)
		
		assert(position > 0 and position < 10, "Invalid note position")
		
		if bit.rshift(note_effect, 31) == 1 then
			-- Long note
			effect_new_val = bit.band(note_effect, 0x3FFFFFF0) / 16000
			effect_new = bit.band(note_effect, 0x40000000) > 0 and 13 or 3
		else
			local is_token = bit.band(note_effect, 16) == 16
			local is_star = bit.band(note_effect, 32) == 32
			
			if is_token and not(is_star) then
				effect_new = 2
			elseif is_star and not(is_token) then
				effect_new = 4
			elseif is_star and is_token then
				effect_new = 11
			end
		end
		
		sif_notes[#sif_notes + 1] = {
			timing_sec = timing_sec,
			notes_attribute = attribute,
			notes_level = 1,
			effect = effect_new,
			effect_value = effect_new_val,
			position = position
		}
	end
	
	table.sort(sif_notes, function(a, b) return a.timing_sec < b.timing_sec end)
	return sif_notes
end

--! @brief Beatmap Tick parser
--! @param stream The file stream
--! @returns SIF-compilant beatmap
local function process_BMPT(stream)
	local sif_notes = {}
	local ppqn = string2word(stream:read(2))
	local bpm = string2word(stream:read(2)) / 1000
	local highest_tick = 0
	local current_timing = 0
	local add_timing = 60 / bpm * ppqn
	local amount_notes = string2dwordu(stream:read(4))
	local events_list = {}
	
	-- Convert to events
	for i = 1, amount_notes do
		local event = {}
		local additional_event
		local attribute
		local note_effect
		
		event.tick = string2dwordu(stream:read(4))
		attribute = string2dwordu(stream:read(4))
		note_effect = string2dwordu(stream:read(4))
		
		if attribute == 4294967295 then
			-- BPM change
			event.new_tempo = note_effect
		else
			local position = bit.band(note_effect, 15)
			local effect_new_val = 2
			local effect_new = 1
			
			event.position = position
			event.notes_attribute = attribute
			event.notes_level = 1
			
			-- Note data
			if bit.rshift(note_effect, 31) == 1 then
				-- Long note
				effect_new_val = bit.band(note_effect, 0x3FFFFFF0) / 16000
				effect_new = bit.band(note_effect, 0x40000000) > 0 and 13 or 3
				additional_event = {
					tick = event.tick + effect_new_val,
					notes_attribute = attribute,
					position = position,
					notes_end = true
				}
				
				highest_tick = math.max(highest_tick, additional_event.tick)
			else
				-- Single tap note
				local is_token = bit.band(note_effect, 16) == 16
				local is_star = bit.band(note_effect, 32) == 32
				
				highest_tick = math.max(highest_tick, event.tick)
				
				if is_token and not(is_star) then
					effect_new = 2
				elseif is_star and not(is_token) then
					effect_new = 4
				elseif is_star and is_token then
					effect_new = 11
				end
			end
			
			event.effect = effect_new
			event.effect_value = effect_new_val
		end
		
		events_list[#events_list + 1] = event
		
		if additional_event then
			events_list[#events_list + 1] = additional_event
		end
	end
	
	-- Converts all events to SIF notes data
	local longnote_queue = {}
	for i = 0, highest_tick do
		local event = events_list[1]
		
		while i >= event.tick do
			if event.new_tempo then
				-- BPM change
				bpm = event.new_tempo
				add_timing = 60 / bpm * ppqn
			else
				-- Note data
				local attr_identifier = string.format("%d_%08x", event.position, event.attribute)
				
				if event.effect == 3 then
					assert(longnote_queue[attr_identifier] == nil, "Overlapped long note")
					
					event.timing_sec = current_timing
					
					longnote_queue[attr_identifier] = event
				elseif event.notes_end then
					local queue_ev = assert(longnote_queue[attr_identifier], "End note before long note")
					
					queue_ev.tick = nil
					queue_ev.effect_value = current_timing - queue_ev.timing_sec
					sif_notes[#sif_notes + 1] = event
				else
					queue_ev.tick = nil
					queue_ev.timing_sec = current_timing
					sif_notes[#sif_notes + 1] = event
				end
			end
			
			table.remove(events_list, 1)
			event = events_list[1]
		end
		
		current_timing = current_timing + add_timing
	end
	
	table.sort(sif_notes, function(a, b) return a.timing_sec < b.timing_sec end)
	return sif_notes
end

--! @brief Score value section processing
--! @param stream The file stream
--! @returns Table containing the score requirements for C, B, A and S score
local function process_SCRI(stream)
	return {
		string2dword(stream:read(4)),
		string2dword(stream:read(4)),
		string2dword(stream:read(4)),
		string2dword(stream:read(4))
	}
end

--! @brief Lua storyboard section
--! @param stream The file stream
--! @param path Beatmap path or nil if not in DEPLS beatmap folder
--! @returns Lua storyboard object
local function process_SRYL(stream, path)
	local storyboard = readstring(stream)
	
	do
		local a, b = pcall(love.math.decompress, storyboard, "zlib")
		
		storyboard = a and b or storyboard
	end
	
	return LuaStoryboard.LoadString(storyboard, path)
end

--! @brief Custom unit image section
--! @param stream The file stream
--! @returns Unit image index and unit Image object
local function process_UIMG(stream)
	
	return
		stream:read(1):byte(),
		love.graphics.newImage(love.filesystem.newFileData(readstring(stream), randstring(8).. ".png"))
end

local function process_UNIT(stream)
	local list = {}
	
	for i = 1, stream:read(1):byte() do
		list[#list + 1] = {stream:read(1):byte(), stream:read(1):byte()}
	end
	
	return list
end

local process_BIMG = process_UIMG	-- Literally same

--! @brief Process additional data
--! @param stream The file stream
--! @returns Filename and the FileData object (2 values)
local function process_DATA(stream)
	local filename = readstring(stream)
	
	return
		filename,
		love.filesystem.newFileData(readstring(stream), filename)
end

--! @brief Returns audio from ADIO section
--! @param stream The file stream
--! @returns SoundData object
local function process_ADIO(stream)
	local extension = {[0] = ".wav", ".ogg", ".mp3"}
	local ext = stream:read(1):byte()
	
	assert(extension[ext], "Invalid extension")
	
	return love.sound.newSoundData(love.filesystem.newFileData(
		readstring(stream),
		"_" .. extension[ext]
	))
end

--! @brief Loads cover information
--! @param stream The file stream
local function process_COVR(stream)
	local title = readstring(stream)
	local arr = readstring(stream)
	local img = love.graphics.newImage(love.filesystem.newFileData(
		readstring(stream),
		"cover.png"
	))
	
	if #title == 0 then title = nil end
	if #arr == 0 then arr = nil end
	
	return {
		title = title,
		arrangement = arr,
		image = img
	}
end

--! @brief Parse LS2 beatmap from specificed stream
--! @param stream The file stream
--! @param path DEPLS beatmap folder directory or nil if not in DEPLS beatmap folder
--! @returns See NoteLoader.NoteLoader()
function ls2.parsestream(stream, path)
	local output = {notes_list = {}}
	local ndata = {}
	local uimg_data = {}
	local unit_data = {}
	local bimg_data = {}
	local additional_data = {}
	local section_amount
	local backgroundid
	local force_ns
	local staminadisp
	local scoretap
	
	assert(assert(stream:read(8)) == "livesim2", "Invalid LS2 beatmap file")
	
	section_amount = string2wordu(stream:read(2))
	backgroundid = stream:read(1):byte()
	force_ns = math.floor(backgroundid / 16)
	backgroundid = backgroundid % 16
	staminadisp = stream:read(1):byte()
	scoretap = string2wordu(stream:read(2))
	
	for i = 1, section_amount do
		local section = stream:read(4)
		
		if section == "BMPM" then
			ndata[#ndata + 1] = process_BMPM(stream)
		elseif section == "BMPT" then
			ndata[#ndata + 1] = process_BMPT(stream)
		elseif section == "SCRI" then
			assert(output.score == nil, "Only one SCRI can exist")
			output.score = process_SCRI(stream)
		elseif section == "SRYL" then
			assert(output.storyboard == nil, "Only one SRYL can exist")
			output.storyboard = process_SRYL(stream, path)
		elseif section == "UIMG" then
			local a, b = process_UIMG(stream)
			
			uimg_data[a] = b
		elseif section == "UNIT" then
			local list = process_UNIT(stream)
			
			for i = 1, #list do
				unit_data[list[i][1]] = list[i][2]
			end
		elseif section == "BIMG" then
			local a, b = process_BIMG(stream)
			
			bimg_data[a] = b
		elseif section == "DATA" then
			local a, b = process_DATA(stream)
			
			additional_data[a] = b
		elseif section == "ADIO" then
			assert(output.song_file == nil, "Only one ADIO can exist")
			output.song_file = process_ADIO(stream)
		elseif section == "COVR" then
			assert(output.cover == nil, "Only one COVR can exist")
			output.cover = process_COVR(stream)
		elseif section == "LCLR" then
			assert(output.live_clear == nil, "Only one LCLR can exist")
			output.live_clear = love.audio.newSource(process_ADIO(stream))
		else
			io.write("Invalid section ", section, "\n")
		end
	end
	
	assert(#ndata > 0, "At least one of BMPM or BMPT must be exist")
	
	-- Merge notes list
	for i = 1, #ndata do
		for j = 1, #ndata[i] do
			output.notes_list[#output.notes_list + 1] = ndata[i][j]
		end
	end
	
	do table.sort(output.notes_list, function(a, b) return a.timing_sec < b.timing_sec end) end
	
	-- If there's storyboard, add file search from additional datas
	if output.storyboard then
		output.storyboard:SetAdditionalFiles(additional_data)
	end
	
	-- Background ID or background data. Background data has higher priority
	if bimg_data[0] then
		output.background = bimg_data
	elseif backgroundid > 0 then
		output.background = backgroundid
	end
	
	if force_ns > 0 then
		output.note_style = force_ns
	end
	
	-- Unit data checking
	local new_unit_data = {}
	local has_unit_data = false
	
	for i = 1, 9 do
		if unit_data[i] then
			new_unit_data[i] = assert(uimg_data[unit_data[i]], "Unit data points to invalid image index")
			has_unit_data = true
		end
	end
	
	if has_unit_data then
		output.units = new_unit_data
	end
	
	-- Score tap check
	if scoretap > 0 then
		output.scoretap = scoretap
	end
	
	-- Stamina display check
	if staminadisp < 127 then
		output.staminadisp = math.min(staminadisp, 99)
	end
	
	return output
end

--! @brief Parse LS2 beatmap file from filename
--! @param file The filename
--! @param path DEPLS beatmap folder directory or nil if it's not in DEPLS beatmap folder
--! @returns See NoteLoader.NoteLoader
function ls2.parsefile(file, path)
	local f
	
	if type(file) == "string" then
		f = assert(io.open(file, "rb"))
	end
	
	return ls2.parsestream(f, path)
end

---------------------------------
-- TODO: LS2 Encoder Code Here --
---------------------------------

return ls2
