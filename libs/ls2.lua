-- Live Simulator: 2 binary beatmap loader
-- Part of Live Simulator: 2 v2.x
--[[---------------------------------------------------------------------------
-- Copyright (c) 2041 Dark Energy Processor Corporation
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
--]]---------------------------------------------------------------------------

local ls2 = {
	_VERSION = "2.0.1",
	_LICENSE = "Copyright \169 2041 Dark Energy Processor, licensed under MIT/Expat.",
	_AUTHOR  = "Dark Energy Processor Corporation",
	encoder = {}
}
local bit = require("bit")

---------------------------------------------------
-- File reading/writing wrapper, for consistency --
---------------------------------------------------
local fileptr = getmetatable(io.stdout)
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

-- Double word to little-endian string (unsigned)
local function dwordu2string(num)
	local b = {}
	b[1] = string.char(bit.band(num, 0xFF))
	b[2] = string.char(bit.rshift(bit.band(num, 0xFF00), 8))
	b[3] = string.char(bit.rshift(bit.band(num, 0xFF0000), 16))
	b[4] = string.char(bit.rshift(bit.band(num, 0xFF000000), 24))

	return table.concat(b)
end

-- Double word to little-endian string (signed)
local function dword2string(num)
	return dwordu2string(num % 4294967296)
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

local function wordu2string(num)
	local b = {}
	b[1] = string.char(bit.band(num, 0xFF))
	b[2] = string.char(bit.rshift(bit.band(num, 0xFF00), 8))

	return table.concat(b)
end

-- String read datatype
local function readstring(stream)
	return fsw.read(stream, string2dwordu(fsw.read(stream, 4)))
end

local function writestring(stream, data)
	fsw.write(stream, dwordu2string(#data))
	fsw.write(stream, data)
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

	out.song_file = readstring(stream)
	if #out.song_file == 0 then out.song_file = nil end

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
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)))
	fsw.seek(stream, "cur", string2dwordu(fsw.read(stream, 4)) + 32)
end

--! @brief Beatmap Millisecond parser
--! @param stream The file stream
--! @param v2 use v2.0 parsing method?
--! @returns SIF-compilant beatmap
local function process_BMPM(stream, v2)
	local sif_notes = {}
	local amount_notes = string2dwordu(fsw.read(stream, 4))

	for _ = 1, amount_notes do
		local effect_new = 1
		local effect_new_val = 2
		local notes_level = 1
		local timing_sec = string2dwordu(fsw.read(stream, 4)) / 1000
		local attribute = string2dwordu(fsw.read(stream, 4))
		local note_effect = string2dwordu(fsw.read(stream, 4))
		local position = bit.band(note_effect, 0xF)

		assert(position > 0 and position < 10, "Invalid note position")

		if v2 then
			effect_new = bit.band(bit.rshift(note_effect, 4), 3) + 1

			if effect_new == 3 then
				effect_new_val = bit.band(bit.rshift(note_effect, 6), 0x3FFFF) * 0.001
			end

			-- Swing note
			if bit.band(attribute, 16) > 0 then
				notes_level = bit.rshift(note_effect, 24) + 1
				effect_new = effect_new + 10
				attribute = attribute - 16	-- Strip swing note flag
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
	for _ = 1, amount_notes do
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
				effect_new = bit.band(bit.rshift(note_effect, 4), 3) + 1

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
					event.notes_level = bit.band(note_effect, 24) + 1
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
				else
					local queue_ev = assert(longnote_queue[attr_identifier], "End note before long note")
					queue_ev.tick = nil

					if event.notes_end then
						queue_ev.effect_value = current_timing - queue_ev.timing_sec
					else
						queue_ev.timing_sec = current_timing
					end

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
--! @returns Storyboard Lua script (possibly compressed)
local function process_SRYL(stream)
	return readstring(stream)
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
		list[i] = {fsw.read(stream, 1):byte(), fsw.read(stream, 1):byte()}
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
	BIMG = {process_UIMG, skip_UIMG},
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

	for _ = 1, section_count do
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
	assert(this.version_2 and this.sections.MTDT or not(this.version_2), "No metadata section found")

	return this
end

------------------------------------------------
-- LS2 Encoder. Creates LS2 v2.0 beatmap file --
------------------------------------------------
local ls2enc = {}
local ls2enc_index = {__index = ls2enc}

local function write_MTDT(stream, metadata)
	local n = 0
	local starinfo = 0
	local has_star = metadata.star and metadata.star > 0
	local has_rstar = has_star and metadata.random_star and metadata.random_star > 0

	if type(metadata.score) == "table" then n = n + 1 end
	if type(metadata.combo) == "table" then n = n + 2 end
	if has_star then
		n = n + 4
		starinfo = starinfo + bit.band(metadata.star, 15)
	end
	if has_rstar then
		n = n + 8
		starinfo = starinfo + bit.lshift(bit.band(metadata.random_star, 15), 4)
	end

	fsw.write(stream, string.char(n))
	fsw.write(stream, string.char(starinfo))
	writestring(stream, metadata.name or "")
	writestring(stream, metadata.song_file or "")

	if metadata.score then
		for i = 1, 4 do fsw.write(stream, dword2string(metadata.score[i])) end
	else
		fsw.write(stream, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
	end

	if metadata.combo then
		for i = 1, 4 do fsw.write(stream, dword2string(metadata.combo[i])) end
	else
		fsw.write(stream, "\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0\0")
	end
end

local function write_BMPM(stream, sif_beatmap)
	fsw.write(stream, dwordu2string(#sif_beatmap))

	for i = 1, #sif_beatmap do
		local note = sif_beatmap[i]
		local actual_effect = note.effect % 10
		local swing_note = note.effect > 10

		-- Attribute bits
		local attribute = (bit.band(note.notes_attribute, 0xFFFFFFEF) % 4294967296)
		attribute = attribute + (swing_note and 16 or 0)

		-- Note effect bits
		local note_effect = note.position
		note_effect = note_effect + bit.lshift(bit.band(actual_effect - 1, 3), 4)

		if actual_effect == 3 then
			note_effect = note_effect + bit.lshift(bit.band(math.floor(note.effect_value * 1000), 0x3FFFF), 6)
		end

		if swing_note and note.notes_level > 1 then
			note_effect = note_effect + (((note.notes_level - 1) % 254) + 2) * 16777216
		end

		fsw.write(stream, dwordu2string(math.floor(note.timing_sec * 1000)))
		fsw.write(stream, dwordu2string(attribute))
		fsw.write(stream, dwordu2string(note_effect))
	end
end

local function write_SRYL(stream, story)
	writestring(stream, story)
end

local function write_UIMG(stream, uimg)
	fsw.write(stream, string.char(assert(uimg.index)))
	writestring(stream, assert(uimg.image))
end

local function write_UNIT(stream, unit_info)
	fsw.write(stream, string.char(#unit_info))

	for i = 1, #unit_info do
		local a = unit_info[i]

		fsw.write(stream, string.char(assert(a.position)))
		fsw.write(stream, string.char(assert(a.index)))
	end
end

local function write_DATA(stream, data)
	writestring(stream, data.filename)
	writestring(stream, data.contents)
end

local function write_ADIO(stream, adio_data)
	fsw.write(stream, string.char(assert(adio_data.audio_type)))

	if adio_data.extension then
		writestring(stream, adio_data.extension .. adio_data.audio_data)
	else
		writestring(stream, adio_data.audio_data)
	end
end

local function write_COVR(stream, cover)
	writestring(stream, assert(cover.image))
	writestring(stream, cover.title or "")
	writestring(stream, cover.arrangement or "")
end

ls2enc.section_processor = {
	MTDT = write_MTDT,
	BMPM = write_BMPM,
	SRYL = write_SRYL,
	UIMG = write_UIMG,
	UNIT = write_UNIT,
	BIMG = write_UIMG,
	DATA = write_DATA,
	ADIO = write_ADIO,
	COVR = write_COVR,
	LCLR = write_ADIO
}

function ls2enc.new(dest, metadata)
	local this = setmetatable({}, ls2enc_index)

	this.background_id = 0
	this.note_style = 0
	this.stamina = 255
	this.score = 0

	this.sections_list = {}
	this.sections_list_by_type = {}
	this.stream = assert(dest, "Output stream missing")

	return this:_add_section("MTDT", assert(metadata, "Beatmap metadata missing"))
end

function ls2enc._add_section(this, name, contents)
	local s = {}
	local stype = this.sections_list_by_type[name]
	s.name = name
	s.data = contents

	this.sections_list[#this.sections_list + 1] = s

	if not(stype) then
		stype = {}
		this.sections_list_by_type[name] = stype
	end

	stype[#stype + 1] = s
	return this
end

function ls2enc._count_section(this, name)
	if not(name) then
		return #this.sections_list
	else
		return this.sections_list_by_type[name] and #this.sections_list_by_type[name] or 0
	end
end

function ls2enc.set_background_id(this, id)
	local new_id = id == nil and 0 or id
	assert(new_id >= 0 and new_id <= 15, "Background ID out of range")

	this.background_id = new_id
	return this
end

function ls2enc.set_notes_style(this, style)
	if style == nil or style == "none" then
		this.note_style = 0
	elseif style == 1 or style == "old" then
		this.note_style = 1
	elseif style == 2 or style == "v5" then
		this.note_style = 2
	else
		assert(false, "Invalid note style value")
	end

	return this
end

function ls2enc.set_stamina(this, stamina)
	local new_st = (stamina == 0 or stamina == nil) and 255 or stamina
	assert((new_st > 0 and new_st < 100) or new_st == 255, "Invalid stamina value")

	this.stamina = new_st
	return this
end

function ls2enc.set_score(this, score)
	if score == nil then
		this.score = 0
	else
		assert(score > 0, "Invalid base score tap value")
		this.score = score
	end

	return this
end

function ls2enc.add_beatmap(this, sif_beatmap)
	return this:_add_section("BMPM", sif_beatmap)
end

function ls2enc.add_storyboard(this, storyboard)
	assert(this:_count_section("SRYL") == 0, "Storyboard already added")

	if type(storyboard) == "function" then
		io.stderr:write("Warning: Compiled storyboard is discouraged!\n")
		storyboard = string.dump(storyboard)
	end

	return this:_add_section("SRYL", storyboard)
end

function ls2enc.add_unit_image_list(this, unit_image)
	for i = 1, #unit_image do
		this:_add_section("UIMG", unit_image[i])
	end

	return this
end

function ls2enc.add_unit_image(this, unit_image)
	return this:_add_section("UIMG", unit_image)
end

function ls2enc.add_unit_info_list(this, unit)
	return this:_add_section("UNIT", unit)
end

function ls2enc.add_unit_info(this, unit)
	return this:_add_section("UNIT", {unit})
end

function ls2enc.add_custom_background(this, background, index)
	local bimg = {}
	bimg.index = index or 0
	bimg.image = assert(background, "Background image missing")

	return this:_add_section("BIMG", bimg)
end

function ls2enc.add_storyboard_data(this, filename, contents)
	local data = {}
	data.filename = assert(filename, "Filename missing")
	data.contents = assert(contents, "Contents missing")

	return this:_add_section("DATA", data)
end

function ls2enc._internal_add_audio(this, section, audio_type, audio_data, failmsg)
	assert(this:_count_section(section) == 0, failmsg)
	local audio = {}

	if audio_type == "wav" or audio_type == "wave" then
		audio.audio_type = 0
	elseif audio_type == "vorbis" then
		audio.audio_type = 1
	elseif audio_type == "mp3" then
		audio.audio_type = 2
	else
		local extension = select(2, audio_type:find("custom:", 1, true))
		assert(extension, "Unknown audio type")

		local ext = audio_type:sub(extension + 1)
		if ext:sub(1, 1) ~= "." then
			ext = "."..ext
		end

		audio.extension = ext
		audio.audio_type = 15 + bit.lshift(#ext, 4)
	end

	audio.audio_data = audio_data
	return this:_add_section(section, audio)
end

function ls2enc.add_audio(this, at, ad)
	return this:_internal_add_audio("ADIO", at, ad, "Beatmap audio already added")
end

function ls2enc.add_cover_art(this, cover)
	assert(this:_count_section("COVR") == 0, "Cover art already added")
	return this:_add_section("COVR", cover)
end

function ls2enc.add_live_clear_voice(this, at, ad)
	return this:_internal_add_audio("LCLR", at, ad, "Live clear voice already added")
end

function ls2enc.write(this)
	local stream = this.stream
	fsw.seek(stream, "set")

	-- Write contents
	fsw.write(stream, "livesim2")
	fsw.write(stream, wordu2string(this:_count_section()))
	fsw.write(stream, string.char(
		bit.band(this.background_id, 15) +            -- Background ID
		bit.lshift(bit.band(this.note_style, 7), 4) + -- Note style
		128                                           -- Live Simulator: 2 beatmap version 2.0
	))
	fsw.write(stream, string.char(this.stamina))
	fsw.write(stream, wordu2string(this.score))

	-- Loop through all section data and write
	for i = 1, #this.sections_list do
		local sect = this.sections_list[i]

		fsw.write(stream, sect.name)
		assert(ls2enc.section_processor[sect.name], "Unknown section")(stream, sect.data)
	end

	-- Done
end

ls2.encoder = ls2enc
return ls2
