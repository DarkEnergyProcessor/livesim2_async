-- Beatmap converter, using built-in Live Simulator: 2 note loader
-- Part of Live Simulator: 2

local NoteConvert = {}
local JSON = require("JSON")

function NoteConvert.Start(arg)
	local NoteLoader = assert(love.filesystem.load("note_loader.lua"))()
	local _, noteloader_data = pcall(NoteLoader.NoteLoader, arg[1])
	
	if _ == false then
		io.stderr:write(noteloader_data)
	else
		io.write(JSON:encode(noteloader_data.notes_list))
	end
	
	love.event.quit()
end

return NoteConvert
