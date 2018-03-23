-- Musical note icon (Lovewing)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local love = require("love")
local NoteIcon = {}

local function init()
	NoteIcon.Note = AquaShine.LoadImage("assets/image/lovewing/center.png")
	NoteIcon.Scale = 0
	return NoteIcon
end

function NoteIcon.Update()
	-- According to Lovewing, the musical note icon should be
	-- the beat, but some mobile devices can't do beat detection
	-- fast enough, so we use the current audio samples instead.
	local smp = DEPLS.StoryboardFunctions.GetCurrentAudioSample(16)
	NoteIcon.Scale = 0

	for i = 1, 4 do
		NoteIcon.Scale = NoteIcon.Scale + math.abs(smp[i][1]) ^ 2 + math.abs(smp[i][2]) ^ 2
	end

	NoteIcon.Scale = math.min(math.sqrt(NoteIcon.Scale / 32), 1) -- 16 samples * 2 channels
	NoteIcon.Scale = 0.47 + NoteIcon.Scale * 0.35 -- Min is 0.47, max is 0.72
end

function NoteIcon.Draw()
	-- Due to SIF limitation, musical note icon position
	-- must be in 480x160

	love.graphics.setColor(58/255, 244/255, 102/255)
	love.graphics.draw(NoteIcon.Note, 480, 160, 0, NoteIcon.Scale, NoteIcon.Scale, 55, 59.5)
end

return init()
