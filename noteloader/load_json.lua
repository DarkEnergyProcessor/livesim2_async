-- JSON-based beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local love = love
local JSON = require("JSON")

local JSONLoader = NoteLoader.NoteLoaderLoader:extend("NoteLoader.JSONLoader", {ProjectLoader = false})

--------------------------
-- JSON Beatmap Loaders --
--------------------------

local Loaders = {
	SIF = assert(love.filesystem.load("noteloader/json_sif.lua"))(AquaShine, NoteLoader),
	SIFT = assert(love.filesystem.load("noteloader/json_sift.lua"))(AquaShine, NoteLoader),
	LLP = assert(love.filesystem.load("noteloader/json_llp.lua"))(AquaShine, NoteLoader),
}

function JSONLoader.GetLoaderName()
	return "JSON-based Beatmap Loader"
end

function JSONLoader.LoadNoteFromTable(bm, file)
	local loader
	if
		bm.song_info and
		bm.song_info[1] and
		bm.song_info[1].notes and
		bm.rank_info and
		bm.song_name
	then
		-- SIFTrain
		loader = Loaders.SIFT(bm, file)
	elseif bm.lane and bm.audiofile then
		-- LLP
		loader = Loaders.LLP(bm, file)
	else
		-- SIF
		loader = Loaders.SIF(bm, file)
	end
	
	return loader
end

function JSONLoader.LoadNoteFromFilename(f, file)
	local fs, bm, loader
	
	assert(f:read(30):find("%s*{"), "Not a valid JSON beatmap")
	f:seek(0)
	
	fs = f:read()
	bm = JSON:decode(fs)
	
	return JSONLoader.LoadNoteFromTable(bm, file)
end

return JSONLoader
