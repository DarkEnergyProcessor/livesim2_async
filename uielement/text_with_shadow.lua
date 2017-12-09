-- Drawable text with shadow
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local Node = AquaShine.Node
local love = love

local TextShadow = Node.Colorable:extend("Livesim2.TextShadow")

function TextShadow.init(this, font, text, x, y)
	this.text = love.graphics.newText(font or AquaShine.LoadFont(nil, 14), text)
	this.actualtext = text
	
	return Node.Colorable.init(this)
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
end

function TextShadow.setShadow(this, dist, blackness, doubleside, noupdate)
	this.shadow = {dist, blackness, doubleside}
	
	if not(noupdate) then
		return this:refresh()
	end
end

function TextShadow.setText(this, text, noupdate)
	this.actualtext = text
	
	if not(noupdate) then
		return this:refresh()
	end
end

function TextShadow.draw(this)
	love.graphics.setColor(this.color)
	love.graphics.draw(this.text, this.x, this.y)
	
	return Node.Colorable.draw(this)
end

return TextShadow
