-- Lovewing score bar
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local love = require("love")
local ScoreUpdate = DEPLS.Routines.ScoreUpdate
local ScoreData = DEPLS.ScoreData
local ScoreBar = {}

ScoreBar.Colors = {
	{1, 1, 153/255},       -- No score
	{0, 1, 1},             -- C score
	{1, 153/255, 68/255},  -- B score
	{1, 153/255, 153/255}, -- A score
	{187/255, 170/255, 1}  -- S score
}
ScoreBar.CurrentColor = ScoreBar.Colors[1]

local function init()
	ScoreBar.Glow = AquaShine.LoadImage("assets/image/lovewing/glow_score.png")

	return ScoreBar
end

function ScoreBar.Update()
	if ScoreUpdate.CurrentScore >= ScoreData[4] then
		-- S score
		ScoreBar.CurrentColor = ScoreBar.Colors[5]
	elseif ScoreUpdate.CurrentScore >= ScoreData[3] then
		-- A score
		ScoreBar.CurrentColor = ScoreBar.Colors[4]
	elseif ScoreUpdate.CurrentScore >= ScoreData[2] then
		-- B score
		ScoreBar.CurrentColor = ScoreBar.Colors[3]
	elseif ScoreUpdate.CurrentScore >= ScoreData[1] then
		-- C score
		ScoreBar.CurrentColor = ScoreBar.Colors[2]
	else
		-- No score
		ScoreBar.CurrentColor = ScoreBar.Colors[1]
	end
end

function ScoreBar.Draw()
	-- No matter what happend, we just need to draw rectangle
	local w = math.min(ScoreUpdate.CurrentScore / ScoreData[4], 1) * 872
	love.graphics.setColor(207/255, 207/255, 207/255, DEPLS.LiveOpacity)
	love.graphics.rectangle("fill", 44, 84, 872, 8)
	love.graphics.rectangle("line", 44, 84, 872, 8)
	love.graphics.setColor(ScoreBar.CurrentColor[1], ScoreBar.CurrentColor[2], ScoreBar.CurrentColor[3], DEPLS.LiveOpacity)
	love.graphics.rectangle("fill", 44, 84, w, 8)
	love.graphics.rectangle("line", 44, 84, w, 8)
	love.graphics.draw(ScoreBar.Glow, 44, 84, 0, 1, 1, 44, 44)
end

return init()
