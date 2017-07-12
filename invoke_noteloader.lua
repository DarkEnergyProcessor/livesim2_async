-- Beatmap converter, using built-in Live Simulator: 2 NoteLoader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local NoteConvert = {}
local JSON = require("JSON")
local NoteLoader = AquaShine.LoadModule("note_loader2")

function NoteConvert.Start(arg)
	local noteloader_data = NoteLoader.NoteLoader(assert("beatmap/"..arg[1]))
	
	io.write(JSON:encode(noteloader_data:GetNotesList()))
	love.event.quit()
end

return NoteConvert
