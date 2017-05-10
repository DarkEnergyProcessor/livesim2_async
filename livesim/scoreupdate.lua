-- Score display
local DEPLS = ...
local ScoreUpdate = {CurrentScore = 0}

local draw = love.graphics.draw
local setColor = love.graphics.setColor
local score_str = {string.byte(tostring(ScoreUpdate.CurrentScore), 1, 2147483647)}
local score_images = {}
local score_digit_len = 0
local xpos

for i = 0, 9 do
	score_images[i] = love.graphics.newImage("assets/image/live/score_num/l_num_0"..i..".png")
end

function ScoreUpdate.Update(deltaT)
	score_str = {string.byte(tostring(ScoreUpdate.CurrentScore), 1, 2147483647)}
	score_digit_len = #score_str
	xpos = 448 - 16 * score_digit_len
end

function ScoreUpdate.Draw()
	setColor(255, 255, 255, DEPLS.LiveOpacity)
	
	for i = 1, score_digit_len do
		draw(score_images[score_str[i] - 48], xpos + 32 * i, 53)
	end
	
	setColor(255, 255, 255, 255)
end

return ScoreUpdate
