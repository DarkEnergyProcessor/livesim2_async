-- Wrapper of livesim.lua invocation via Command-Line
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local NoteLoader = AquaShine.LoadModule("note_loader2")
local DEPLS = assert(love.filesystem.load("livesim.lua"))(AquaShine)
local DEPLS_Start = DEPLS.Start

function DEPLS.Start(arg)
	-- First argument must be the beatmap
	local beatmap = assert(arg[1], "Specify beatmap")
	
	return DEPLS_Start({Beatmap = assert(NoteLoader.NoteLoader("beatmap/"..beatmap), "Beatmap not found: "..beatmap)})
end

return DEPLS
