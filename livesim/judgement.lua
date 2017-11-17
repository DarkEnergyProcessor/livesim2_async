-- Combo judgement animation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = love
local DEPLS = ...
local PerfectNode = {}

local scaling = 2	-- Text size: FULL = 2, Small = 1.6, Mini = 1
local et = 500
local perfect_data = {opacity = 0, scale = 0}
local perfect_tween = tween.new(50, perfect_data, {opacity = 1, scale = 1}, "outSine")
local perfect_tween_fadeout = tween.new(200, perfect_data, {opacity = 0})

perfect_tween:update(50)
perfect_tween_fadeout:update(200)

function PerfectNode.Update(deltaT)
	et = et + deltaT
	
	if PerfectNode.Replay then
		et = deltaT
		perfect_tween:reset()
		perfect_tween_fadeout:reset()
		PerfectNode.Replay = false
	end
	
	perfect_tween:update(deltaT)
	
	if et > 170 then
		perfect_tween_fadeout:update(deltaT)
	end
	
	-- To prevent overflow
	if et > 5000 then
		et = et - 4000
	end
end

function PerfectNode.Draw()
	if et < 500 then
		love.graphics.setColor(1, 1, 1, perfect_data.opacity * DEPLS.LiveOpacity)
		love.graphics.draw(
			PerfectNode.Image, 480, 320, 0,
			perfect_data.scale * DEPLS.TextScaling,
			perfect_data.scale * DEPLS.TextScaling,
			PerfectNode.Center[PerfectNode.Image][1],
			PerfectNode.Center[PerfectNode.Image][2]
		)
		love.graphics.setColor(1, 1, 1)
	end
end

return PerfectNode
