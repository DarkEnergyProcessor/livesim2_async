-- Combo judgement animation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = require("love")
local DEPLS, AquaShine = ...
local PerfectNode = {}

local et = 500
local perfect_data = {opacity = 0, scale = 0}
local perfect_tween = tween.new(50, perfect_data, {opacity = 1, scale = 1}, "outSine")
local perfect_tween_fadeout = tween.new(200, perfect_data, {opacity = 0})

local function init()
	perfect_tween:update(50)
	perfect_tween_fadeout:update(200)

	-- Tap accuracy image
	DEPLS.Images.Perfect = AquaShine.LoadImage("assets/image/live/ef_313_004_w2x.png")
	DEPLS.Images.Great = AquaShine.LoadImage("assets/image/live/ef_313_003_w2x.png")
	DEPLS.Images.Good = AquaShine.LoadImage("assets/image/live/ef_313_002_w2x.png")
	DEPLS.Images.Bad = AquaShine.LoadImage("assets/image/live/ef_313_001_w2x.png")
	DEPLS.Images.Miss = AquaShine.LoadImage("assets/image/live/ef_313_000_w2x.png")
	PerfectNode.Center = {
		[DEPLS.Images.Perfect] = {198, 38},
		[DEPLS.Images.Great] = {147, 35},
		[DEPLS.Images.Good] = {127, 35},
		[DEPLS.Images.Bad] = {86, 33},
		[DEPLS.Images.Miss] = {93, 30}
	}
	PerfectNode.Image = DEPLS.Images.Perfect
	-- Initialize tap accuracy routine
	PerfectNode.Draw()

	return PerfectNode
end

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

return init()
