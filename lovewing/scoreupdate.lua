-- Score display (Lovewing)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local DEPLS, AquaShine = ...
local ScoreUpdate = {CurrentScore = 0}

local function init()
	ScoreUpdate.Venera43 = AquaShine.LoadFont("Venera-700.otf", 43)
	ScoreUpdate.String = ""

	return ScoreUpdate
end

function ScoreUpdate.Update()
	ScoreUpdate.String = tostring(ScoreUpdate.CurrentScore)
end

function ScoreUpdate.Draw()
	local w = ScoreUpdate.Venera43:getWidth(ScoreUpdate.String)

	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
	love.graphics.setFont(ScoreUpdate.Venera43)
	love.graphics.print(ScoreUpdate.String, 480 - w * 0.5, 15)
end

return init()
