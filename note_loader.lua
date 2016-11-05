-- DEPLS Note Loader function
local List = require("List")
local JSON = require("JSON")
local CBFPos = {
	L4 = 9,
	L3 = 8,
	L2 = 7,
	L1 = 6,
	C = 5,
	R1 = 4,
	R2 = 3,
	R3 = 2,
	R4 = 1
}

-- Usage: push from right, pop from left
local noteloader
noteloader = function(path)
	local notes_list = nil
	local storyoard = nil
	local song_file = nil
	
	-- Try to load foldered beatmap data
	if love.filesystem.isDirectory("beatmap/"..path) then
		-- 2 possible: CBF or DEPLS
		
		if love.filesystem.isFile("beatmap/"..path.."/beatmap.json") then
			-- DEPLS beatmap
			local ndata = JSON:decode(assert(love.filesystem.newFileData("beatmap/"..path.."/beatmap.json")):getString())
			notes_list = List.new()
			table.sort(ndata, function(a, b) return a.timing_sec < b.timing_sec end)
			
			for i = 1, #ndata do
				notes_list:pushright(ndata[i])
			end
			
			-- Check if Lua storyboard exist
			if love.filesystem.isFile("beatmap/"..path.."/storyboard.lua") then
				storyboard = require("luastoryboard")
				storyboard.Load("beatmap/"..path.."/storyboard.lua")
			elseif love.filesystem.isFile("beatmap/"..path.."/storyboard.json") then
				-- TODO
			end
			
			song_file = load_audio_safe("beatmap/"..path.."/songFile.wav")
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
		notes_list = List.new()
		table.sort(ndata, function(a, b) return a.timing_sec < b.timing_sec end)
		
		for i = 1, #ndata do
			notes_list:pushright(ndata[i])
		end
	elseif love.filesystem.isFile("beatmap/"..path..".txt") then
		-- SifSimu beatmap
		local sifsimu2sif = require("sifsimu2sif")
		
		sifsimu2sif(love.filesystem.getSaveDirectory().."/beatmap/"..path..".txt", love.filesystem.getSaveDirectory().."/beatmap/"..path..".json")
		
		return noteloader(path)
	else
		-- Unsupported beatmap
		error("Cannot open beatmap \""..path.."\"")
	end
	
	return notes_list, storyboard, song_file
end

return noteloader
