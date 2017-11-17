-- Score display
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local ScoreUpdate = {CurrentScore = 0}

local love = love
local score_str = tostring(ScoreUpdate.CurrentScore)
local score_images = AquaShine.GetCachedData("score_list", love.graphics.newImageFont, "assets/image/live/score_num/score.png", "0123456789", -4)
local xpos

function ScoreUpdate.Update(deltaT)
	score_str = tostring(ScoreUpdate.CurrentScore)
end

function ScoreUpdate.Draw()
	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
	love.graphics.setFont(score_images)
	love.graphics.print(score_str, 476, 53, 0, 1, 1, #score_str * 16, 0)
end

return ScoreUpdate
