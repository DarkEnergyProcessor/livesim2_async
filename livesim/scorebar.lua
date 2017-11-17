-- Score bar render
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local DEPLS, AquaShine = ...
local ScoreBar = {BarTapFlash = true}

local ScoreUpdate = DEPLS.Routines.ScoreUpdate
local ScoreData = DEPLS.ScoreData
local LogicalScale = LogicalScale
local setScissor = love.graphics.setScissor
local setColor = love.graphics.setColor
local draw = love.graphics.draw
local no_score = AquaShine.LoadImage("assets/image/live/live_gauge_03_03.png")
local c_score = AquaShine.LoadImage("assets/image/live/live_gauge_03_04.png")
local b_score = AquaShine.LoadImage("assets/image/live/live_gauge_03_05.png")
local a_score = AquaShine.LoadImage("assets/image/live/live_gauge_03_06.png")
local s_score = AquaShine.LoadImage("assets/image/live/live_gauge_03_07.png")
local s_flash = AquaShine.LoadImage("assets/flash/ui/live/img/ef_318_000.png")
local draw_area = 960
local used_score = nil

local flash_data = {s = 0.75}
local flash_tween = tween.new(1000, flash_data, {s = 0.5})

function ScoreBar.Update(deltaT)
	if ScoreUpdate.CurrentScore >= ScoreData[4] then
		-- S score
		used_score = s_score
		draw_area = 960
		ScoreBar.BarTapFlash = false
		
		if flash_tween:update(deltaT) then
			flash_tween:reset()
		end
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
	AquaShine.SetScissor(0, 0, draw_area, 640)
	setColor(1, 1, 1, DEPLS.LiveOpacity)
	draw(used_score, 5, 8, 0, 0.99545454, 0.86842105)
	
	if used_score == s_score then
		setColor(1, 1, 1, DEPLS.LiveOpacity * flash_data.s)
		draw(s_flash, 36, 3)
	end
	
	setColor(1, 1, 1)
	AquaShine.ClearScissor()
end

return ScoreBar
