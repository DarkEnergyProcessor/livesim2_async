local DEPLS = ...
local love = love
local tween = require("tween")
local SpotEffect = {}

local _cm = {__index = SpotEffect}

function SpotEffect.Create(pos, r, g, b)
	local out = {}
	
	out.r = r
	out.g = g
	out.b = b
	out.idol = assert(DEPLS.IdolPosition[pos], "Invalid position")
	out.direction = DEPLS.AngleFrom(416, 96, out.idol[1], out.idol[2])
	out.infodata = {}
	out.infodata.scale = 1.3333
	out.infodata.opacity = 255
	out.dist = DEPLS.Distance(out.idol[1] - 416, out.idol[2] - 96) / 256
	do
		local temp = {}
		temp.scale = 0
		temp.opacity = 0
		
		out.infotween = tween.new(500, out.infodata, temp)
	end
	
	return setmetatable(out, _cm)
end

function SpotEffect.Update(this, deltaT)
	return this.infotween:update(deltaT)
end

function SpotEffect.Draw(this)
	love.graphics.setBlendMode("add")
	love.graphics.setColor(this.r, this.g, this.b, this.infodata.opacity)
	love.graphics.draw(DEPLS.Images.Spotlight, this.idol[1] + 64, this.idol[2] + 64, this.direction, this.infodata.scale, this.dist, 48, 256)
	love.graphics.setBlendMode("alpha")
	love.graphics.setColor(255, 255, 255)
end

return SpotEffect
