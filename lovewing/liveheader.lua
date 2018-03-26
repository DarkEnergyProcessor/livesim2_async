-- Live header (Lovewing)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local DEPLS, AquaShine = ...
local LiveHeader = {}

local function init()
	LiveHeader.Venera = AquaShine.LoadFont("Venera-700.otf", 14)
	LiveHeader.Pause = AquaShine.LoadImage("assets/image/lovewing/pause.png")
	LiveHeader.Stamina = AquaShine.LoadImage("assets/image/lovewing/circ.png")

	return LiveHeader
end

function LiveHeader.Update()
	if not(LiveHeader.BeatmapName) then
		LiveHeader.BeatmapName = DEPLS.NoteLoaderObject:GetName()

		if #LiveHeader.BeatmapName > 25 then
			LiveHeader.BeatmapName = LiveHeader.BeatmapName:sub(1, 22).."..."
		end
	end

	LiveHeader.NotesString = string.format("Notes %d/%d", DEPLS.NoteManager.NoteRemaining, DEPLS.NoteManager.TotalNotes)
end

function LiveHeader.DrawPause()
	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
	love.graphics.draw(LiveHeader.Pause, 38, 21, 0, 0.19, 0.19)
end

function LiveHeader.Draw()
	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
	love.graphics.draw(LiveHeader.Stamina, 480, 160, 0, 0.75, 0.75, 75, 75)
	love.graphics.setColor(1, 56/255, 2/255, DEPLS.LiveOpacity)
	love.graphics.setFont(LiveHeader.Venera)
	love.graphics.print(LiveHeader.BeatmapName, 62, 62)
	love.graphics.setColor(1, 252/255, 2/255, DEPLS.LiveOpacity)
	love.graphics.print(LiveHeader.NotesString, 62, 48)
	love.graphics.setColor(58/255, 244/255, 102/255)
	love.graphics.print(DEPLS.AutoPlay and "Autoplay" or "Live!", 800, 62)
end

return init()
