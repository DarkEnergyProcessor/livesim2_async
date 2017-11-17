-- Note icon and it's circle
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local DEPLS = ...
local NoteIcon = {}

local Images = DEPLS.Images
local noteicon_data = {scale = 1}
local noteicon_tween = tween.new(800, noteicon_data, {scale = 0.8})
local noteicon_tween2 = tween.new(1400, noteicon_data, {scale = 1}, "outSine")
local noteicon_circle = {}
local active_tween = noteicon_tween
local et = 0

for i = 1, 3 do
	local temp = {
		time = (i - 1) * 300,
		data = {scale = 0.6, opacity = 1},
	}
	temp.tween = tween.new(1600, temp.data, {scale = 2.5, opacity = 0})
	
	noteicon_circle[i] = temp
end

local setColor = love.graphics.setColor
local draw = love.graphics.draw

local function noteicon_draw(i)
	local ni = noteicon_circle[i]
	
	if ni.time <= 0 then
		setColor(1, 1, 1, ni.data.opacity * DEPLS.LiveOpacity)
		draw(Images.NoteIconCircle, 480, 160, 0, ni.data.scale, ni.data.scale, 34, 34)
	end
end

function NoteIcon.Update(deltaT)
	et = et + deltaT
	
	if et >= 2200 then
		et = deltaT
		
		noteicon_tween:reset()
		noteicon_tween2:reset()
		active_tween = noteicon_tween
		noteicon_circle[1].time = 0
		noteicon_circle[1].tween:reset()
		noteicon_circle[2].time = 300
		noteicon_circle[2].tween:reset()
		noteicon_circle[3].time = 600
		noteicon_circle[3].tween:reset()
	end
		
	if active_tween:update(deltaT) == true then
		active_tween = noteicon_tween2
	end
	
	-- Update circle
	for i = 1, 3 do
		local ni = noteicon_circle[i]
		
		ni.time = ni.time - deltaT
		if ni.time <= 0 then
			ni.tween:update(deltaT)
		end
	end
end

function NoteIcon.Draw()
	noteicon_draw(1)
	noteicon_draw(2)
	noteicon_draw(3)
	
	setColor(1, 1, 1, DEPLS.LiveOpacity)
	draw(Images.NoteIcon, 480, 160, 0, noteicon_data.scale, noteicon_data.scale, 54, 52)
	setColor(1, 1, 1)
end

return NoteIcon
