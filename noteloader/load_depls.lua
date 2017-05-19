-- DEPLS beatmap loader
-- Inherited from CBF and SIF beatmap format, 2nd most complex beatmap
-- Part of Live Simulator: 2

local AquaShine, NoteLoader = ...
local JSON = require("JSON")
local DEPLS2Beatmap = {
	Name = "DEPLS Beatmap Folder",
	Extension = nil		-- Detect function is necessary
}

--! @brief Check if specificed beatmap is DEPLS2 beatmap
--! @param file Table contains:
--!        - path relative to DEPLS save dir
--!        - absolute path
--!        - forward slashed and not contain trailing slash
--! @returns true if it's DEPLS2 beatmap, false otherwise
function DEPLS2Beatmap.Detect(file)
	local zip = file[1]..".zip"
	
	if love.filesystem.isFile(zip) then
		AquaShine.MountZip(zip, file[1])
	end
	
	-- Enum loaders
	for i = 1, #NoteLoader.Loaders do
		local loader = NoteLoader.Loaders[i]
		
		if
			(loader.Extension and loader.Extension ~= "txt") or
			(loader.Extension == "txt" and love.filesystem.isFile(file[1].."/projectConfig.txt") == false)
		then
			if love.filesystem.isFile(file[1].."/beatmap."..loader.Extension) then
				return true
			end
		end
	end
			
	return false
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
	local notes_data
	local storyboard
	local scoreinfo
	
	-- Enum loaders
	for i = 1, #NoteLoader.Loaders do
		local loader = NoteLoader.Loaders[i]
		
		if loader.Extension then
			if love.filesystem.isFile(file[1].."/beatmap."..loader.Extension) then
				local out = loader.Load({
					file[1].."/beatmap",
					file[2].."/beatmap"
				}, file[1].."/")
				
				notes_data = out.notes_list
				scoreinfo = out.score
			end
		end
		
		if notes_data then break end
	end
	
	table.sort(notes_data, function(a, b) return a.timing_sec < b.timing_sec end)
	
	-- Get storyboard
	if love.filesystem.isFile(file[1].."/storyboard.lua") then
		storyboard = {Storyboard = love.filesystem.load("luastoryboard.lua")()}
		storyboard.Load = function() storyboard.Storyboard.Load(file[1].."/storyboard.lua") end
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
	
	-- Get cover image
	local covr
	if love.filesystem.isFile(file[1].."/cover.png") then
		covr = {image = love.graphics.newImage(love.filesystem.newFileData(file[1].."/cover.png"))}
		
		if love.filesystem.isFile(file[1].."/cover.txt") then
			local fs = assert(love.filesystem.newFileData(file[1].."/cover.txt")):getString()
			local title, arr = fs:match("([^\r\n|\r|\n]+)[\r\n|\r|\n]*(.*)")
			
			covr.title = title
			if #arr > 0 then
				covr.arrangement = arr
			end
		end
	end
	
	-- Result
	local out = {
		notes_list = notes_data,
		storyboard = storyboard,
		song_file = AquaShine.LoadAudio(file[1].."/songFile.wav"),
		score = scoreinfo,
		cover = covr
	}
	
	local live_clear = AquaShine.LoadAudio(file[1].."/live_clear.wav")
	if live_clear then
		out.live_clear = love.audio.newSource(live_clear)
	end
	
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
