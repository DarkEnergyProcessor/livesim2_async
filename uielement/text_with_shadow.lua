-- Drawable text with shadow
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local TextShadow = AquaShine.Node.Colorable:extend("Livesim2.TextShadow")

function TextShadow.init(this, font, text, x, y)
	AquaShine.Node.Colorable.init(this)
	this.text = love.graphics.newText(font or AquaShine.LoadFont(nil, 14), text)
	this.actualtext = text
	this.x = x or 0
	this.y = y or 0
end

function TextShadow.refresh(this)
	this.text:clear()
	
	-- First add shadow
	if this.shadow then
		this.text:add({{0, 0, 0, this.shadow[2]}, this.actualtext}, this.shadow[1], this.shadow[1])
		
		if this.shadow[3] then
			this.text:add({{0, 0, 0, this.shadow[2]}, this.actualtext}, -this.shadow[1], -this.shadow[1])
		end
	end
	
	-- Draw actual text
	this.text:add(this.actualtext)
	return this
end

function TextShadow.setShadow(this, dist, blackness, doubleside, noupdate)
	if dist == 0 then
		this.shadow = nil
	else
		this.shadow = {dist, blackness, doubleside}
		
		if not(noupdate) then
			return this:refresh()
		end
	end
	
	return this
end

function TextShadow.setText(this, text, noupdate)
	this.actualtext = text
	
	if not(noupdate) then
		return this:refresh()
	end
	
	return this
end

function TextShadow.draw(this)
	if #this.actualtext > 0 then
		love.graphics.setColor(this.color)
		love.graphics.draw(this.text, this.x, this.y)
	end
	
	return AquaShine.Node.Colorable.draw(this)
end

return TextShadow
