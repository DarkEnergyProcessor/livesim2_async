-- DEPLS2 ls2 beatmap loader
-- Part of DEPLS2

local DEPLS = _G.DEPLS
local NoteLoader = _G.NoteLoader
local bit = require("bit")

local LS2Beatmap = {
	Extension = "ls2"
}

-- String read datatype
local function readstring(stream)
	return stream:read(string2dwordu(stream:read(4)))
end

-- String to little endian dword (signed)
local function string2dword(str)
	return bit.bor(
		bit.bor(str:byte(), bit.lshift(str:sub(2,2):byte(), 8)),
		bit.bor(bit.rshift(str:sub(3,3):byte(), 16), bit.rshift(str:sub(4,4):byte(), 24))
	)
end

-- String to little endian dword (unsigned)
local function string2dwordu(str)
	return string2dword(str) % 4294967296
end

-- String to little endian word (unsigned)
local function string2word(str)
	return bit.bor(str:byte(), bit.lshift(str:sub(2,2):byte(), 8))
end

----------------------------------
-- Section processors functions --
----------------------------------

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
			effect_new_val = bit.band(note_effect, 0x7FFFFFF0) / 1000
			effect_new = 3
		else
			local is_token = bit.band(note_effect, 16) == 16
			local is_star = bit.band(note_effect, 32) == 32
			
			if is_token and not(is_star) then
				effect_new = 2
			elseif is_star and not(is_token) then
				effect_new = 4
			elseif is_star and is_token then
				assert(false, "Invalid note effect bits")
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
	
	return sif_notes
end

--! @brief Beatmap Tick parser
--! @param stream The file stream
--! @returns SIF-compilant beatmap
local function process_BMPT(stream)
	local sif_notes = {}
	local ppqn = string2word(stream:read(2))
	local current_timing = 0
	local add_timing = 60 / (string2word(stream:read(2)) * string2dwordu(stream:read(4)))
	local amount_notes = string2dwordu(stream:read(4))
	
	for i = 1, amount_notes do
		local effect_new = 1
		local effect_new_val = 2
		local timing_sec = string2dwordu(stream:read(4)) * add_timing
		local attribute = string2dwordu(stream:read(4))
		local note_effect = string2dwordu(stream:read(4))
		local position = bit.band(note_effect, 15)
		
		assert(position > 0 and position < 10, "Invalid note position")
		
		if bit.rshift(note_effect, 31) == 1 then
			-- Long note
			effect_new_val = bit.band(note_effect, 0x7FFFFFF0) * add_timing
			effect_new = 3
		else
			local is_token = bit.band(note_effect, 16) == 16
			local is_star = bit.band(note_effect, 32) == 32
			
			if is_token and not(is_star) then
				effect_new = 2
			elseif is_star and not(is_token) then
				effect_new = 4
			elseif is_star and is_token then
				assert(false, "Invalid note effect bits")
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
--! @param path Temporary beatmap path
--! @returns Lua storyboard object
local function process_SRYL(stream, path)
	local storyboard = readstring(stream)
	local luastoryboard = love.filesystem.load("luastoryboard.lua")()
	
	luastoryboard.LoadString(storyboard, path)
	return luastoryboard
end

function LS2Beatmap.Load(file)
end
