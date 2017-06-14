-- Live Simulator: 2 NoteLoader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = AquaShine
local JSON = require("JSON")
local love = love

local NoteLoader = {}
local SaveDirectory = love.filesystem.getSaveDirectory()

local loaders = {
	assert(assert(love.filesystem.load("noteloader/load_depls.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_cbf.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_ls2.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_sif.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_sifs.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_sift.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_llp.lua"))(AquaShine, NoteLoader)),
	assert(assert(love.filesystem.load("noteloader/load_mid.lua"))(AquaShine, NoteLoader))
}
NoteLoader.Loaders = loaders

do
	local unit_alr_loaded = {}
	
	--! @brief Loads image relative in beatmap folder
	--! @param BeatmapDir The DEPLS beatmap path
	--! @param Path The image path
	--! @returns Image handle or nil on failure
	function NoteLoader.LoadImageRelative(BeatmapDir, Path)
		if unit_alr_loaded[Path] then
			return unit_alr_loaded[Path]
		end
		
		local x = love.filesystem.newFileData(BeatmapDir.."/"..Path)
		
		if not(x) then return nil end
		
		local y = love.graphics.newImage(x)
		unit_alr_loaded[Path] = y
		
		return y
	end
	
	--! @brief Load unit image with specificed path
	--! @param beatmap_name The DEPLS beatmap path
	--! @param path The unit file name (txt indicates LINK, png indicates image)
	--! @returns The image handle or nil if image can't be loaded
	function NoteLoader.UnitLoader(beatmap_name, path)
		if path:sub(-4) == ".txt" then
			local path_link = assert(love.filesystem.read(beatmap_name.."/"..path))
			
			return NoteLoader.LoadImageRelative(beatmap_name, path_link)
		else
			return NoteLoader.LoadImageRelative(beatmap_name, path)
		end
	end
end

--! @brief Loads notes data
--! @param path The beatmap name
--! @returns Table with these keys:
--!          - notes_list - SIF-Compilant beatmap
--!          - storyboard - Lua storyboard handle or nil
--!          - song_file - Beatmap audio handle or nil
--!          - unit_image - The beatmap-specific unit image or nil
--!			 - background - The beatmap-specific background ID or handle or nil
--!          - score - The beatmap score info (C, B, A, S score in table) or nil
--!          - cover - Beatmap cover image information or nil
--!          - scoretap
--!          - staminadisp
--!          - live_clear
--! @warning This function causes lua error if the beatmap is not found
function NoteLoader.NoteLoader(path)
	path = {
		"beatmap/"..path,
		SaveDirectory.."/beatmap/"..path
	}
	
	for i = 1, #loaders do
		local loader = loaders[i]
		
		if loader.Extension then
			if love.filesystem.isFile(path[1].."."..loader.Extension) then
				return loader.Load(path)
			end
		elseif loader.Extension == nil and loader.Detect then
			if loader.Detect(path) then
				return loader.Load(path)
			end
		else
			assert(false, "Invalid beatmap loader #"..i)
		end
	end
	
	assert(false, "Cannot open beatmap \""..path[1].."\"")
end

--! @brief Enumerates beatmap list in <save directory>/beatmap folder
--! @returns List of beatmaps, with following data:
--!          - name, beatmap name
--!          - type, beatmap format
function NoteLoader.Enumerate()
	local files = love.filesystem.getDirectoryItems("beatmap/")
	local beatmap_list = {}
	
	for n, v in ipairs(files) do
		local found = false
		local name = v:match("(.*)%..*") or v
		
		for a, b in ipairs(beatmap_list) do
			if b.name == name then
				found = true
				break
			end
		end
		
		if not(found) then
			local btype
			local path = {
				"beatmap/"..name,
				SaveDirectory.."/beatmap/"..name
			}
			
			for i = 1, #loaders do
				local loader = loaders[i]
				
				-- Detect it
				if loader.Extension then
					if love.filesystem.isFile(path[1].."."..loader.Extension) then
						btype = loaders[i].Name
					end
				elseif loader.Extension == nil and loader.Detect then
					if loader.Detect(path) then
						btype = loaders[i].Name
					end
				else
					assert(false, "Invalid beatmap loader "..i)
				end
				
				if btype then break end
			end
			
			if btype then
				beatmap_list[#beatmap_list + 1] = {
					name = name,
					type = btype
				}
			end
		end
	end
	
	return beatmap_list
end

function NoteLoader.DetectSpecific(file, with_detect_only)
	local path = {}
	path[1] = file
	path[2] = SaveDirectory.."/"..file
	
	for i = 1, #loaders do
		local loader = loaders[i]
		
		if not(with_detect_only) and loader.Extension then
			if love.filesystem.isFile(path[1].."."..loader.Extension) then
				return true
			end
		elseif loader.Extension == nil and loader.Detect then
			if loader.Detect(path) then
				return true
			end
		else
			assert(false, "Invalid beatmap loader #"..i)
		end
	end
	
	return false
end

return NoteLoader
