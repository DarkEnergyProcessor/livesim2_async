-- DEPLS Note Loader function
local JSON = require("JSON")
local DEPLS = require("DEPLS")
local love = love

local testbeatmap = {{"dwr", "ogg"} , {"1154_mod", "ogg"}}
local noteloader

--! @brief Loads notes data
--! @param path The beatmap name
--! @returns Three values:
--!          - SIF-Compilant beatmap
--!          - Lua storyboard handle (or nil)
--!          - Beatmap audio handle (or nil)
--! @warning This function causes lua error if the beatmap is not found
noteloader = function(path)
	local notes_list = nil
	local storyboard = nil
	local song_file = nil
	
	if path:find("::%d+") then
		-- Test beatmap
		local idx = tonumber(path:match("::(%d+)"))
		local bm = testbeatmap[idx]
		
		if bm == nil then
			error("Invalid test beatmap")
		end
		
		return JSON:decode(assert(love.filesystem.newFileData("test/"..bm[1]..".json")):getString()),
			   nil, love.audio.newSource("test/"..bm[1].."."..bm[2], "static")
	end
	
	-- Try to load foldered beatmap data
	if love.filesystem.isDirectory("beatmap/"..path) then
		-- 2 possible: CBF or DEPLS
		
		if love.filesystem.isFile("beatmap/"..path.."/beatmap.json") then
			-- DEPLS beatmap
			local ndata = JSON:decode(assert(love.filesystem.newFileData("beatmap/"..path.."/beatmap.json")):getString())
			table.sort(ndata, function(a, b) return a.timing_sec < b.timing_sec end)
			
			notes_list = ndata
			
			-- Check if Lua storyboard exist
			if love.filesystem.isFile("beatmap/"..path.."/storyboard.lua") then
				storyboard = require("luastoryboard")
				storyboard.Load("beatmap/"..path.."/storyboard.lua")
			elseif love.filesystem.isFile("beatmap/"..path.."/storyboard.json") then
				-- TODO
			end
			
			song_file = DEPLS.LoadAudio("beatmap/"..path.."/songFile.wav")
		elseif love.filesystem.isFile("beatmap/"..path.."/beatmap.txt") and love.filesystem.isFile("beatmap/"..path.."/projectConfig.txt") then
			-- CBF beatmap
			local cbf2sif = require("cbf2sif")
			cbf2sif(love.filesystem.getSaveDirectory().."/beatmap/"..path, love.filesystem.getSaveDirectory().."/beatmap/"..path.."/beatmap.json")
			
			-- Convert done. Retry load as DEPLS beatmap folder
			return noteloader(path)
		end
	elseif love.filesystem.isFile("beatmap/"..path..".json") then
		-- SIF beatmap
		local ndata = JSON:decode(assert(love.filesystem.newFileData("beatmap/"..path..".json")):getString())
		table.sort(ndata, function(a, b) return a.timing_sec < b.timing_sec end)
		
		notes_list = ndata
	elseif love.filesystem.isFile("beatmap/"..path..".txt") then
		-- SifSimu beatmap
		local sifsimu2sif = require("sifsimu2sif")
		
		sifsimu2sif(love.filesystem.getSaveDirectory().."/beatmap/"..path..".txt", love.filesystem.getSaveDirectory().."/beatmap/"..path..".json")
		
		return noteloader(path)
	elseif love.filesystem.isFile("beatmap/"..path..".mid") then
		-- MIDI beatmap
		local midi2sif = require("midi2sif")
		local f = assert(io.open(love.filesystem.getSaveDirectory().."/beatmap/"..path..".mid", "rb"))
		local ndata = midi2sif(f)
		
		f:close()
		
		notes_list = ndata
	else
		-- Unsupported beatmap
		error("Cannot open beatmap \""..path.."\"")
	end
	
	return notes_list, storyboard, song_file
end

return noteloader
