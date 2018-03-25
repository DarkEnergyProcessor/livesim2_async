-- Combo counter animation (Lovewing)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = require("love")
local DEPLS, AquaShine = ...
local ComboCounter = {CurrentCombo = 0}

local function init()
	ComboCounter.VeneraCombo = AquaShine.LoadFont("Venera-700.otf", 22)
	ComboCounter.VeneraComboX = AquaShine.LoadFont("Venera-700.otf", 14)

	ComboCounter.Scale = 1.5
	ComboCounter.ScaleData = tween.new(250, ComboCounter, {Scale = 1}, "outSine")
	ComboCounter.ScaleData:update(1000)

	return ComboCounter
end

function ComboCounter.Update(deltaT)
	if ComboCounter.Replay then
		ComboCounter.Scale = 1.5
		ComboCounter.ScaleData:reset()
		ComboCounter.Replay = false
	end

	-- Don't draw if combo is 0
	if ComboCounter.CurrentCombo > 0 then
		ComboCounter.ScaleData:update(deltaT)
	end
end

function ComboCounter.Draw()
	if ComboCounter.CurrentCombo > 0 then
		love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
		love.graphics.setFont(ComboCounter.VeneraComboX)
		love.graphics.print("combo x", 392, 232)

		local text = string.format("%d", ComboCounter.CurrentCombo)
		local w = ComboCounter.VeneraCombo:getWidth(text)
		love.graphics.setFont(ComboCounter.VeneraCombo)
		love.graphics.push()
		love.graphics.translate(w * 0.5 + 490, 13 + 225) -- font h = 26
		love.graphics.scale(ComboCounter.Scale, ComboCounter.Scale)
		love.graphics.print(text, -w * 0.5, -13)
		love.graphics.pop()
	end
end

return init()
