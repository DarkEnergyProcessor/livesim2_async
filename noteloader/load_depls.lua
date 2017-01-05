-- DEPLS2 beatmap loader
-- Inherited from CBF and SIF beatmap format, most complex beatmap
-- Part of DEPLS2

local DEPLS = _G.DEPLS
local NoteLoader = DEPLS.NoteLoader
local JSON = require("JSON")
local DEPLS2Beatmap = {
	Extension = nil		-- Detect function is necessary
}

--! @brief Check if specificed beatmap is DEPLS2 beatmap
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns true if it's DEPLS2 beatmap, false otherwise
function DEPLS2Beatmap.Detect(file)
	return love.filesystem.isFile(file[1].."/beatmap.json")
end

--! @brief Loads DEPLS2 beatmap
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns table with these data
--!          - notes_list is the SIF-compilant notes data
--!          - song_file is the song file handle (Source object) or nil
--!          - storyboard is the DEPLS2 beatmap storyboard object handle or nil if no storyboard is present
--!          - background is beatmap-specific background ID or handle list (extended backgrounds) (jpg supported) or nil
--!          - units is custom units image list or nil
function DEPLS2Beatmap.Load(file)
	local notes_data = JSON:decode(love.filesystem.newFileData(file[1].."/beatmap.json"):getString())
	local storyboard
	
	table.sort(notes_data, function(a, b) return a.timing_sec < b.timing_sec end)
	
	-- Get storyboard
	if love.filesystem.isFile(file[1].."/storyboard.lua") then
		storyboard = love.filesystem.load("luastoryboard.lua")()
		storyboard.Load(file[1].."/storyboard.lua")
	end
	
	-- Get background
	local background = {}
	local background_id
	
	if love.filesystem.isFile(file[1].."/background.txt") then
		-- Background ID
		background_id = assert(tonumber(love.filesystem.newFileData(file[1].."/background.txt"):getString()))
	else
		-- Background handle
		local exts = {"png", "jpg", "bmp"}
		
		for a, b in pairs(exts) do
			if love.filesystem.isFile(file[1].."/background."..b) then
				background[0] = NoteLoader.LoadImageRelative(file[1], "background."..b)
			end
		end
		
		-- Left, Right, Top, Bottom
		if background[0] then
			for i = 1, 4 do
				for j = 1, 3 do
					local b = exts[j]
					
					if love.filesystem.isFile(file[1].."/background-"..i.."."..b) then
						background[i] = NoteLoader.LoadImageRelative(file[1], "background-"..i.."."..b)
						break
					end
				end
			end
		end
	end
	
	-- Get units
	local units_ext = {"png", "txt"}
	local units = {}
	local has_custom_units = false
	
	for i = 1, 9 do
		for j = 1, 2 do
			if love.filesystem.isFile(file[1].."/unit_pos_"..i.."."..units_ext[j]) then
				units[i] = NoteLoader.UnitLoader(file[1], "unit_pos_"..i.."."..units_ext[j])
				has_custom_units = true
				break
			end
		end
	end
	
	-- Result
	local out = {
		notes_list = notes_data,
		storyboard = storyboard,
		song_file = DEPLS.LoadAudio(file[1].."/songFile.wav")
	}
	
	if background_id then
		out.background = background_id
	elseif background[0] then
		out.background = background
	end
	
	if has_custom_units then
		out.units = units
	end
	
	return out
end

return DEPLS2Beatmap
