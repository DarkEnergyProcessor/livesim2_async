-- Combo counter animation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = require("love")
local DEPLS, AquaShine = ...
local ComboCounter = {CurrentCombo = 0}

local combo_scale = {s = 1.15}
local combo_tween = tween.new(150, combo_scale, {s = 1}, "inOutSine")
local combo_boom = {s = 1.25, op = 0.5}
local combo_boom_tween = tween.new(330, combo_boom, {s = 1.65, op = 0})

local function init()
	-- Load image
	ComboCounter.Images = {}
	for i = 1, 10 do
		ComboCounter.Images[i] = AquaShine.LoadImage("assets/image/live/combo/"..i..".png")
	end
	-- Quad init
	ComboCounter.Part = {
		love.graphics.newQuad(0, 0, 48, 48, 240, 130),
		love.graphics.newQuad(48, 0, 48, 48, 240, 130),
		love.graphics.newQuad(96, 0, 48, 48, 240, 130),
		love.graphics.newQuad(144, 0, 48, 48, 240, 130),
		love.graphics.newQuad(192, 0, 48, 48, 240, 130),
		love.graphics.newQuad(0, 48, 48, 48, 240, 130),
		love.graphics.newQuad(48, 48, 48, 48, 240, 130),
		love.graphics.newQuad(96, 48, 48, 48, 240, 130),
		love.graphics.newQuad(144, 48, 48, 48, 240, 130),
		love.graphics.newQuad(192, 48, 48, 48, 240, 130),
		combo = love.graphics.newQuad(0, 96, 123, 34, 240, 130)
	}
	-- SpriteBatch. First index is "combo" string, second is "combo" shadow effect, the rest is number.
	ComboCounter.Sprite = love.graphics.newSpriteBatch(ComboCounter.Images[1], 12, "stream")
	ComboCounter.ID = {}
	for i = 1, 12 do
		ComboCounter.ID[i] = ComboCounter.Sprite:add(0, 0, 0, 0, 0)
	end

	return ComboCounter
end

local function get_combo_num_idx(combo)
	if combo < 50 then
		-- 0-49
		return 1
	elseif combo < 100 then
		-- 50-99
		return 2
	elseif combo < 200 then
		-- 100-199
		return 3
	elseif combo < 300 then
		-- 200-299
		return 4
	elseif combo < 400 then
		-- 300-399
		return 5
	elseif combo < 500 then
		-- 400-499
		return 6
	elseif combo < 600 then
		-- 500-599
		return 7
	elseif combo < 1000 then
		-- 600-999
		return 8
	elseif combo < 2000 then
		-- 1000-1999
		return 9
	else
		-- >= 2000
		return 10
	end
end

function ComboCounter.Update(deltaT)
	if ComboCounter.Replay then
		combo_tween:reset()
		combo_boom_tween:reset()
		ComboCounter.Replay = false
	end

	-- Don't draw if combo is 0
	if ComboCounter.CurrentCombo > 0 then
		local combo_str = {string.byte(tostring(ComboCounter.CurrentCombo), 1, 10)}
		combo_tween:update(deltaT)
		combo_boom_tween:update(deltaT)

		-- Set texture
		local idx = get_combo_num_idx(ComboCounter.CurrentCombo)
		if idx ~= ComboCounter.LastIndex then
			ComboCounter.Sprite:setTexture(ComboCounter.Images[idx])
			ComboCounter.LastIndex = idx
		end

		-- set "combo"
		ComboCounter.Sprite:setColor(1, 1, 1, combo_boom.op)
		ComboCounter.Sprite:set(ComboCounter.ID[2], ComboCounter.Part.combo, 61, -54, 0, combo_boom.s, combo_boom.s, 61, 17)
		ComboCounter.Sprite:setColor(1, 1, 1)
		ComboCounter.Sprite:set(ComboCounter.ID[1], ComboCounter.Part.combo, 61, -54, 0, combo_scale.s, combo_scale.s, 61, 17)

		-- set numbers
		for i = 1, #combo_str do
			ComboCounter.Sprite:set(
				ComboCounter.ID[i + 2],
				ComboCounter.Part[combo_str[i] - 47],
				-29 - (#combo_str - i) * 43, -53, 0,
				combo_scale.s, combo_scale.s, 24, 24
			)
		end
		-- clean previous batch
		for i = #combo_str + 1, 10 do
			ComboCounter.Sprite:set(ComboCounter.ID[i + 2], 0, 0, 0, 0, 0)
		end
	end
end

-- "combo" pos: 541x267+61+17
-- number pos: 451x267+24+24; align right; subtract by 43 for distance
-- ImageMagick coordinate notation is used
function ComboCounter.Draw()
	if ComboCounter.CurrentCombo > 0 then
		love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
		love.graphics.draw(ComboCounter.Sprite, 480, 320 - 8 * (1 - DEPLS.TextScaling), 0, DEPLS.TextScaling)
	end
end

return init()
