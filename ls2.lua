-- Live Simulator: 2 binary beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local ls2 = {
	_VERSION = "2.0",
	_LICENSE = "Copyright \169 2038 Dark Energy Processor, licensed under MIT/Expat. See copyright notice in Live Simulator: 2 main.lua",
	_AUTHOR  = "Dark Energy Processor Corporation",
	encoder = {}
}
local bit = require("bit")
local love = require("love")
local LuaStoryboard = require("luastoryboard2")

---------------------------------------------------
-- File reading/writing wrapper, for consistency --
---------------------------------------------------
local fileptr = debug.getregistry()["FILE*"]
local fsw = {
	read = fileptr.read,
	write = fileptr.write,
	seek = fileptr.seek,
}

function ls2.setstreamwrapper(list)
	fsw.read = assert(list.read)
	fsw.write = assert(list.write)
	fsw.seek = assert(list.seek)
end

---------------
-- Utilities --
---------------

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
	return fsw.read(stream, string2dwordu(fsw.read(stream, 4)))
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

--! @brief Metadata parser (v2.0, optional in v1.x)
--! @param stream The file stream
--! @returns Metadata in table
local function process_MTDT(stream)
	local out = {}
	
	local has_info = fsw.read(stream, 1):byte()
	local star_info = fsw.read(stream, 1):byte()
	
	out.name = readstring(stream)
	if #out.name == 0 then out.name = nil end
	
	if bit.band(has_info, 4) > 0 then
		-- Has star information
		out.star = bit.band(star_info, 0xF)
		assert(out.star > 0, "Star info present but it's 0")
	end
	
	if bit.band(has_info, 8) > 0 then
		-- Has random star information
		out.random_star = bit.rshift(star_info, 4)
		assert(out.random_star > 0, "Star info present but it's 0")
	else
		out.random_star = out.star
	end
	
	if bit.band(has_info, 1) > 0 then
		-- Has score
		out.score = {
			string2dwordu(fsw.read(stream, 4)),
			string2dwordu(fsw.read(stream, 4)),
			string2dwordu(fsw.read(stream, 4)),
			string2dwordu(fsw.read(stream, 4))
		}
	else
		fsw.read(stream, 16)
	end
	
	if bit.band(has_info, 2) > 0 then
		-- Has combo
		out.combo = {
			string2dwordu(fsw.read(stream, 4)),
			string2dwordu(fsw.read(stream, 4)),
			string2dwordu(fsw.read(stream, 4)),
			string2dwordu(fsw.read(stream, 4))
		}
	else
		fsw.read(stream, 16)
	end
	
	return out
end

local function skip_MTDT(stream)
	fsw.seek(stream, "cur", 2)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)) + 32)
end

--! @brief Beatmap Millisecond parser
--! @param stream The file stream
--! @param v2 use v2.0 parsing method?
--! @returns SIF-compilant beatmap
local function process_BMPM(stream, v2)
	local sif_notes = {}
	local amount_notes = string2dwordu(fsw.read(stream, 4))
	
	for i = 1, amount_notes do
		local effect_new = 1
		local effect_new_val = 2
		local notes_level = 1
		local timing_sec = string2dwordu(fsw.read(stream, 4)) / 1000
		local attribute = string2dwordu(fsw.read(stream, 4))
		local note_effect = string2dwordu(fsw.read(stream, 4))
		local position = bit.band(note_effect, 15)
		
		assert(position > 0 and position < 10, "Invalid note position")
		
		if v2 then
			effect_new = bit.band(bir.rshift(note_effect, 4), 3) + 1
			
			if effect_new == 3 then
				effect_new_val = bit.band(bit.rshift(note_effect, 6), 262143) * 0.001
			end
			
			-- Swing note
			if bit.band(attribute, 16) > 0 then
				notes_level = bit.band(note_effect, 24) + 1
				effect_new = effect_new + 10
			end
		else
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
		end
		
		sif_notes[#sif_notes + 1] = {
			timing_sec = timing_sec,
			notes_attribute = attribute,
			notes_level = notes_level,
			effect = effect_new,
			effect_value = effect_new_val,
			position = position
		}
	end
	
	table.sort(sif_notes, function(a, b) return a.timing_sec < b.timing_sec end)
	return sif_notes
end

local function skip_BMPM(stream)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)) * 12)
end

--! @brief Beatmap Tick parser
--! @param stream The file stream
--! @param v2 use v2.0 parsing method?
--! @returns SIF-compilant beatmap
local function process_BMPT(stream, v2)
	local sif_notes = {}
	local ppqn = string2word(fsw.read(stream, 2))
	local bpm = string2word(fsw.read(stream, 2)) / 1000
	local highest_tick = 0
	local current_timing = 0
	local add_timing = 60 / bpm * ppqn
	local amount_notes = string2dwordu(fsw.read(stream, 4))
	local events_list = {}
	
	-- Convert to events
	for i = 1, amount_notes do
		local event = {}
		local additional_event
		local attribute
		local note_effect
		
		event.tick = string2dwordu(fsw.read(stream, 4))
		attribute = string2dwordu(fsw.read(stream, 4))
		note_effect = string2dwordu(fsw.read(stream, 4))
		
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
			if v2 then
				effect_new = bit.band(bir.rshift(note_effect, 4), 3) + 1
				
				if effect_new == 3 then
					effect_new_val = bit.band(bit.rshift(note_effect, 6), 262143)
					additional_event = {
						tick = event.tick + effect_new_val,
						notes_attribute = attribute,
						position = position,
						notes_end = true
					}
					
					highest_tick = math.max(highest_tick, additional_event.tick)
				end
				
				if bit.band(attribute, 16) > 0 then
					notes_level = bit.band(note_effect, 24) + 1
					effect_new = effect_new + 10
				end
			else
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

local function skip_BMPT(stream)
	fsw.seek(stream, "cur", 6)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)) * 12)
end

--! @brief Score value section processing (v1.x only, ignored in v2.0)
--! @param stream The file stream
--! @returns Table containing the score requirements for C, B, A and S score
local function process_SCRI(stream)
	return {
		string2dword(fsw.read(stream, 4)),
		string2dword(fsw.read(stream, 4)),
		string2dword(fsw.read(stream, 4)),
		string2dword(fsw.read(stream, 4))
	}
end

local function skip_SCRI(stream)
	fsw.seek(stream, "cur", 16)
end

--! @brief Lua storyboard section
--! @param stream The file stream
--! @returns Storyboard Lua script
local function process_SRYL(stream)
	local storyboard = readstring(stream)
	
	do
		local a, b = pcall(love.math.decompress, storyboard, "zlib")
		
		storyboard = a and b or storyboard
	end
	
	return storyboard
end

local function skip_SRYL(stream)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
end

--! @brief Custom unit image section
--! @param stream The file stream
--! @returns Unit image index and unit image PNG string
local function process_UIMG(stream)
	
	return fsw.read(stream, 1):byte(), readstring(stream)
end

local function skip_UIMG(stream)
	fsw.seek(stream, "cur", 1)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
end

--! @brief Custom unit position mapping
--! @param stream The file stream
--! @returns Mapping of custom unit image position
local function process_UNIT(stream)
	local list = {}
	
	for i = 1, fsw.read(stream, 1):byte() do
		list[#list + 1] = {fsw.read(stream, 1):byte(), fsw.read(stream, 1):byte()}
	end
	
	return list
end

local function skip_UNIT(stream)
	fsw.seek(stream, "cur", fsw.read(stream, 1):byte() * 2)
end

--! @brief Process additional data
--! @param stream The file stream
--! @returns Filename and the file contents (2 values)
local function process_DATA(stream)
	return readstring(stream), readstring(stream)
end

local function skip_DATA(stream)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
end

--! @brief Returns audio from ADIO section
--! @param stream The file stream
--! @returns Extension, audio object, and if FFmpeg extension is needed (bool)
local function process_ADIO(stream)
	local extension = {[0] = "wav", "ogg", "mp3"}
	local ext = fsw.read(stream, 1):byte()
	local ext_low = bit.band(ext, 15)
	
	if ext_low == 15 then
		if ls2.has_ffmpegext then
			local extlen = bit.rshift(ext, 4)
			local strdata = readstring(stream)
			
			return strdata:sub(1, 3), strdata:sub(extlen + 1), true
		else
			assert(false, "File not supported")
		end
	elseif ext_low < 3 then
		return extension[ext], readstring(stream)
	end
end

local function skip_ADIO(stream)
	fsw.seek(stream, "cur", 1)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
end

--! @brief Loads cover information
--! @param stream The file stream
--! @param v2 use v2.0 parsing method?
local function process_COVR(stream, v2)
	local img, title, arr
	
	if v2 then
		img = readstring(stream)
		title = readstring(stream)
		arr = readstring(stream)
	else
		title = readstring(stream)
		arr = readstring(stream)
		img = readstring(stream)
	end
	
	if #title == 0 then title = nil end
	if #arr == 0 then arr = nil end
	assert(#img > 0)
	
	return {
		title = title,
		arrangement = arr,
		image = img
	}
end

local function skip_COVR(stream)
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
end

ls2.section_processor = {
	ADIO = {process_ADIO, skip_ADIO},
	BIMG = {process_UNIT, skip_UNIT},
	BMPM = {process_BMPM, skip_BMPM},
	BMPT = {process_BMPT, skip_BMPT},
	COVR = {process_COVR, skip_COVR},
	DATA = {process_DATA, skip_DATA},
	LCLR = {process_ADIO, skip_ADIO},
	MTDT = {process_MTDT, skip_MTDT},
	SCRI = {process_SCRI, skip_SCRI},
	SRYL = {process_SRYL, skip_SRYL},
	UIMG = {process_UIMG, skip_UIMG},
	UNIT = {process_UNIT, skip_UNIT}
}

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
	
	assert(assert(fsw.read(stream, 8)) == "livesim2", "Invalid LS2 beatmap file")
	
	section_amount = string2wordu(fsw.read(stream, 2))
	backgroundid = fsw.read(stream, 1):byte()
	force_ns = math.floor(backgroundid / 16)
	backgroundid = backgroundid % 16
	staminadisp = fsw.read(stream, 1):byte()
	scoretap = string2wordu(fsw.read(stream, 2))
	
	for i = 1, section_amount do
		local section = fsw.read(stream, 4)
		
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

function ls2.loadstream(stream)
	local this = {}
	assert(fsw.read(stream, 8) == "livesim2", "Invalid signature. Expected \"livesim2\"")
	
	local section_count = string2wordu(fsw.read(stream, 2))
	local bginfo = fsw.read(stream, 1):byte()
	
	this.sections = {}
	this.background_id = bit.band(bginfo, 15)
	this.note_style = bit.band(bit.rshift(bginfo, 4), 7)
	this.version_2 = bginfo > 127
	this.stamina_display = fsw.read(stream, 1):byte()
	
	if this.stamina_display == 255 then
		this.stamina_display = nil
	end
	
	this.score_tap = string2wordu(fsw.read(stream, 2))
	
	if this.score_tap == 0 then
		this.score_tap = nil
	end
	
	for i = 1, section_count do
		local fourcc = fsw.read(stream, 4)
		
		assert(ls2.section_processor[fourcc], "Unknown section "..fourcc)
		
		local sect_this = this.sections[fourcc]
		if not(sect_this) then
			sect_this = {}
			this.sections[fourcc] = sect_this
		end
		
		sect_this[#sect_this + 1] = fsw.seek(stream, "cur")
		ls2.section_processor[fourcc][2](stream)	-- Skip
	end
	
	assert(this.sections.BMPM or this.sections.BMPT, "No beatmap data found")
	assert(this.version_2 and this.sections.MTDR or not(this.version_2), "No metadata section found")
	
	return this
end

---------------------------------
-- TODO: LS2 Encoder Code Here --
---------------------------------

return ls2
