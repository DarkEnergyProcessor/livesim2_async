-- Cover Art Loading (when it's still downloading)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local CoverArtLoading = AquaShine.Node:extend("Livesim2.CoverArtLoading")

function CoverArtLoading.init(this)
	AquaShine.Node.init(this)
	this.opacity = 0
	this.circleimg = AquaShine.LoadImage("assets/image/circleeffect_2.png")
end

function CoverArtLoading.update(this, deltaT)
	this.opacity = (this.opacity - deltaT * 0.001) % 1
	return AquaShine.Node.update(this, deltaT)
end

function CoverArtLoading.draw(this)
	local r,g,b,a = love.graphics.getColor()
	love.graphics.setColor(1, 1, 1)
	if this.image then
		love.graphics.draw(this.image, this.x, this.y, 0, 160 / this.imagew, 160 / this.imageh)
	else
		love.graphics.rectangle("fill", this.x, this.y, 160, 160)
		love.graphics.setColor(0, 0, 0, this.opacity)
		love.graphics.draw(this.circleimg, this.x + 42.5, this.y + 42.5)
	end
	love.graphics.setColor(r,g,b,a)
	
	return AquaShine.Node.draw(this)
end

function CoverArtLoading.setImage(this, image)
	this.image = image
	this.imagew = nil
	this.imageh = nil
	
	if this.image then
		this.imagew, this.imageh = image:getDimensions()
	end
	
	return this
end

return CoverArtLoading
