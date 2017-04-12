-- Score bar render
local DEPLS = ...
local ScoreBar = {}

local ScoreUpdate = DEPLS.Routines.ScoreUpdate
local ScoreData = DEPLS.ScoreData
local LogicalScale = LogicalScale
local setScissor = love.graphics.setScissor
local setColor = love.graphics.setColor
local draw = love.graphics.draw
local no_score = love.graphics.newImage("image/live_gauge_03_03.png")
local c_score = love.graphics.newImage("image/live_gauge_03_04.png")
local b_score = love.graphics.newImage("image/live_gauge_03_05.png")
local a_score = love.graphics.newImage("image/live_gauge_03_06.png")
local s_score = love.graphics.newImage("image/live_gauge_03_07.png")
local draw_area = 960
local used_score = nil

function ScoreBar.Update(deltaT)
	if ScoreUpdate.CurrentScore >= ScoreData[4] then
		-- S score
		used_score = s_score
		draw_area = 960
	elseif ScoreUpdate.CurrentScore >= ScoreData[3] then
		-- A score
		used_score = a_score
		draw_area = 791 + math.floor((ScoreData[3] - ScoreUpdate.CurrentScore) / (ScoreData[3] - ScoreData[4]) * 84 + 0.5)
	elseif ScoreUpdate.CurrentScore >= ScoreData[2] then
		-- B score
		used_score = b_score
		draw_area = 667 + math.floor((ScoreData[2] - ScoreUpdate.CurrentScore) / (ScoreData[2] - ScoreData[3]) * 125 + 0.5)
	elseif ScoreUpdate.CurrentScore >= ScoreData[1] then
		-- C score
		used_score = c_score
		draw_area = 504 + math.floor((ScoreData[1] - ScoreUpdate.CurrentScore) / (ScoreData[1] - ScoreData[2]) * 164 + 0.5)
	else
		-- No score
		used_score = no_score
		draw_area = 48 + math.floor(ScoreUpdate.CurrentScore / ScoreData[1] * 456 + 0.5)
	end
end

function ScoreBar.Draw()
	setScissor(LogicalScale.OffX, LogicalScale.OffY, draw_area * LogicalScale.ScaleOverall, 640)
	setColor(255, 255, 255, DEPLS.LiveOpacity)
	draw(used_score, 5, 8, 0, 0.99545454, 0.86842105)
	setColor(255, 255, 255, 255)
	setScissor()
end

return ScoreBar
