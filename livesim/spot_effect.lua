-- Umm, I forgot this one lol
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS = ...
local love = love
local tween = require("tween")
local SpotEffect = {}

local _cm = {__index = SpotEffect}

function SpotEffect.Create(pos, r, g, b)
	local out = {}
	
	out.r = r / 255
	out.g = g / 255
	out.b = b / 255
	out.idol = assert(DEPLS.IdolPosition[pos], "Invalid position")
	out.direction = DEPLS.AngleFrom(416, 96, out.idol[1], out.idol[2])
	out.infodata = {}
	out.infodata.scale = 1.3333
	out.infodata.opacity = 1
	out.dist = DEPLS.Distance(out.idol[1] - 416, out.idol[2] - 96) / 256
	do
		out.infotween = tween.new(500, out.infodata, {scale = 0, opacity = 0})
	end
	
	return (setmetatable(out, _cm))
end

function SpotEffect.Update(this, deltaT)
	return this.infotween:update(deltaT)
end

function SpotEffect.Draw(this)
	love.graphics.setBlendMode("add")
	love.graphics.setColor(this.r, this.g, this.b, this.infodata.opacity)
	love.graphics.draw(DEPLS.Images.Spotlight, this.idol[1] + 64, this.idol[2] + 64, this.direction, this.infodata.scale, this.dist, 48, 256)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(1, 1, 1)
end

return SpotEffect
