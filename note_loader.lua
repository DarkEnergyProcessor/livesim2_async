-- DEPLS Note Loader function
local JSON = require("JSON")
local DEPLS = _G.DEPLS
local love = love

local testbeatmap = {{"dwr", "ogg"} , {"1154_mod", "ogg"}}
local noteloader

local unit_loader
do
	local unit_alr_loaded = {}
	
	local function load_image_rel_beatmap(BeatmapDir, path)
		if unit_alr_loaded[path] then
			return unit_alr_loaded[path]
		end
		
		local x = love.filesystem.newFileData(BeatmapDir.."/"..path)
		
		if not(x) then return nil end
		
		local y = love.graphics.newImage(x)
		unit_alr_loaded[path] = y
		
		return y
	end
	
	--! @brief Load unit image with specificed path
	--! @param beatmap_name The DEPLS beatmap path
	--! @param path The unit file name (txt indicates LINK, png indicates image)
	--! @returns The image handle or nil if image can't be loaded
	function unit_loader(beatmap_name, path)
		if path:sub(-4) == ".txt" then
			local path_link = assert(love.filesystem.newFileData(beatmap_name.."/"..path)):getString()
			
			return load_image_rel_beatmap(beatmap_name, path_link)
		else
			return load_image_rel_beatmap(beatmap_name, path)
		end
	end
end

--! @brief Loads notes data
--! @param path The beatmap name
--! @returns Table with these keys:
--!          - notes_list - SIF-Compilant beatmap
--!          - storyboard - Lua storyboard handle (or nil)
--!          - song_file - Beatmap audio handle (or nil)
--!          - unit_image - The beatmap-specific unit image
--!			 - background - The beatmap-specific background ID or handle
--! @warning This function causes lua error if the beatmap is not found
noteloader = function(path)
	local notes_list = nil
	local storyboard = nil
	local song_file = nil
	local beatmap_path = "beatmap/"..path
	local beatmap_path_full = love.filesystem.getSaveDirectory().."/beatmap/"..path
	local output = {}
	
	if path:find("::%d+") then
		-- Test beatmap
		local idx = tonumber(path:match("::(%d+)"))
		local bm = testbeatmap[idx]
		
		if bm == nil then
			error("Invalid test beatmap")
		end
		
		output.notes_list = JSON:decode(assert(love.filesystem.newFileData("test/"..bm[1]..".json")):getString())
		output.song_file = love.audio.newSource("test/"..bm[1].."."..bm[2], "static")
		
		return output
	end
	
	-- Try to load foldered beatmap data
	if love.filesystem.isDirectory(beatmap_path) then
		-- 2 possible: CBF or DEPLS
		
		if love.filesystem.isFile(beatmap_path.."/beatmap.json") then
			-- DEPLS beatmap
			local ndata = JSON:decode(assert(love.filesystem.newFileData(beatmap_path.."/beatmap.json")):getString())
			table.sort(ndata, function(a, b) return a.timing_sec < b.timing_sec end)
			
			output.notes_list = ndata
			
			-- Check if Lua storyboard exist
			if love.filesystem.isFile(beatmap_path.."/storyboard.lua") then
				output.storyboard = love.filesystem.load("luastoryboard.lua")()
				output.storyboard.Load(beatmap_path.."/storyboard.lua")
			elseif love.filesystem.isFile(beatmap_path.."/storyboard.json") then
				-- TODO
			end
			
			output.song_file = DEPLS.LoadAudio(beatmap_path.."/songFile.wav")
			
			-- Check background
			if love.filesystem.isFile(beatmap_path.."/background.txt") then
				output.background = assert(tonumber(assert(love.filesystem.newFileData(beatmap_path.."/background.txt")):getString()))
			elseif love.filesystem.isFile(beatmap_path.."/background.png") then
				-- TODO
			end
			
			local custom_unit = {}
			-- Check custom unit
			for i = 1, 9 do
				local unit_name_path = "unit_pos_"..i
				
				-- Images has higher priority than link
				if love.filesystem.isFile(beatmap_path.."/"..unit_name_path..".png") then
					custom_unit[i] = unit_loader(beatmap_path, unit_name_path..".png")
				elseif love.filesystem.isFile(beatmap_path.."/"..unit_name_path..".txt") then
					custom_unit[i] = unit_loader(beatmap_path, unit_name_path..".txt")
				end
			end
			
			output.units = custom_unit
		elseif love.filesystem.isFile(beatmap_path.."/beatmap.txt") and love.filesystem.isFile(beatmap_path.."/projectConfig.txt") then
			-- CBF beatmap
			local cbf2sif = require("cbf2sif")
			cbf2sif(beatmap_path_full, beatmap_path_full.."/beatmap.json")
			
			-- Convert done. Retry load as DEPLS beatmap folder
			return noteloader(path)
		end
	elseif love.filesystem.isFile("beatmap/"..path..".json") then
		-- SIF beatmap
		local ndata = JSON:decode(assert(love.filesystem.newFileData("beatmap/"..path..".json")):getString())
		table.sort(ndata, function(a, b) return a.timing_sec < b.timing_sec end)
		
		output.notes_list = ndata
	elseif love.filesystem.isFile("beatmap/"..path..".txt") then
		-- SifSimu beatmap
		local sifsimu2sif = require("sifsimu2sif")
		
		output.notes_list = sifsimu2sif(love.filesystem.getSaveDirectory().."/beatmap/"..path..".txt", love.filesystem.getSaveDirectory().."/beatmap/"..path..".json")
	elseif love.filesystem.isFile("beatmap/"..path..".mid") then
		-- MIDI beatmap
		local midi2sif = require("midi2sif")
		local f = assert(io.open(love.filesystem.getSaveDirectory().."/beatmap/"..path..".mid", "rb"))
		local ndata = midi2sif(f)
		
		f:close()
		
		output.notes_list = ndata
	elseif love.filesystem.isFile("beatmap/"..path..".llp") then
		-- LLPractice beatmap
		local llp2sif = require("llp2sif")
		local ndata = JSON:decode(assert(love.filesystem.newFileData("beatmap/"..path..".llp")):getString())
		
		output.notes_list = llp2sif(ndata)
		
		if ndata.audiofile and #ndata.audiofile > 0 then
			output.song_file = DEPLS.LoadAudio("audio/"..ndata.audiofile..".wav")
		end
	elseif love.filesystem.isFile("beatmap/"..path..".rs") then
		-- SIFTrain beatmap
		error("SIFTrain beatmap format is currently disabled")
		
		local rs2sif = require("rs2sif")
		local ndata = JSON:decode(assert(love.filesystem.newFileData("beatmap/"..path..".rs")):getString())
		
		output.notes_list = rs2sif(ndata)
		
		if ndata.music_file and #ndata.music_file > 0 then
			output.song_file = DEPLS.LoadAudio("audio/"..ndata.music_file..".wav")
		end
		
		if ndata.rank_info then
			output.score = {
				ndata.rank_info[1].rank_max,
				ndata.rank_info[2].rank_max,
				ndata.rank_info[3].rank_max,
				ndata.rank_info[4].rank_max
			}
		end
	else
		-- Unsupported beatmap
		error("Cannot open beatmap \""..path.."\"")
	end
	
	return output
end

return noteloader
