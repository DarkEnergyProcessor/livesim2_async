-- Lovewing circle tap effect
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = require("love")
local DEPLS, AquaShine = ...
local CircleTapEffect = {}
local CircleDest = {
	{scale = 2},
	{opacity = 0}
}
local _common_meta = {__index = CircleTapEffect}

local function init()
	CircleTapEffect.dummy = AquaShine.LoadImage("assets/image/dummy.png")
	return false
end

function CircleTapEffect.Create(x, y, r, g, b)
	local out = {
		x = x,
		y = y,
		r = r,
		g = g,
		b = b,
		circle = {scale = 1, opacity = 0.75}
	}
	out.circleData = {
		tween.new(400, out.circle, CircleDest[1], "outCubic"),
		tween.new(400, out.circle, CircleDest[2], "linear")
	}

	return setmetatable(out, _common_meta)
end

function CircleTapEffect.Update(this, deltaT)
	local s = this.circleData[1]:update(deltaT)
	s = this.circleData[2]:update(deltaT) and s
	return s
end

function CircleTapEffect.Draw(this)
	love.graphics.setColor(this.r, this.g, this.b, this.circle.opacity * DEPLS.LiveOpacity)
	love.graphics.draw(CircleTapEffect.dummy, this.x, this.y, 0, this.circle.scale, this.circle.scale, 64, 64)
end

return init() or CircleTapEffect
