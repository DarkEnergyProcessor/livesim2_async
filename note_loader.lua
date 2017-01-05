-- DEPLS Note Loader function
local DEPLS = _G.DEPLS
local JSON = require("JSON")
local love = love

local testbeatmap = {{"dwr", "ogg"} , {"1154_mod", "ogg"}}
local NoteLoader = {}

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
			local path_link = assert(love.filesystem.newFileData(beatmap_name.."/"..path)):getString()
			
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
--! @warning This function causes lua error if the beatmap is not found
function NoteLoader.NoteLoader(path)
	if path:find("::") == 1 then
		-- Test beatmap
		local id = tonumber(path:match("::(%d+)"))
		local bm = testbeatmap[id]
		
		if bm then
			return {
				notes_list = JSON:decode(love.filesystem.newFileData("test/"..bm[1]..".json"):getString()),
				song_file = love.audio.newSource("test/"..bm[1].."."..bm[2], "static")
			}
		else
			error("Invalid test beatmap ID")
		end
	end
	
	local loadfile = love.filesystem.load
	local loaders = {
		loadfile("noteloader/load_depls.lua")(),
		loadfile("noteloader/load_cbf.lua")(),
		loadfile("noteloader/load_sif.lua")(),
		loadfile("noteloader/load_sifs.lua")(),
		loadfile("noteloader/load_llp.lua")(),
		loadfile("noteloader/load_mid.lua")()
	}
	local path = {
		"beatmap/"..path,
		love.filesystem.getSaveDirectory().."/beatmap/"..path
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
			error("Invalid beatmap loader "..i)
		end
	end
	
	error("Cannot open beatmap \""..path[1].."\"")
end

return NoteLoader
