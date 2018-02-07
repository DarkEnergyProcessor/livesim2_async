-- Checkbox UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local Checkbox = TextShadow:extend("Livesim2.Checkbox")

function Checkbox.init(this, text, x, y, onchange)
	TextShadow.init(this, AquaShine.LoadFont("MTLmr3m.ttf", 22), text, x, y)
	this.userdata.checkbox = AquaShine.LoadImage("assets/image/ui/com_etc_292.png")
	this.userdata.checkbox_check = AquaShine.LoadImage("assets/image/ui/com_etc_293.png")
	this.userdata.is_checked = false
	
	AquaShine.Node.Util.InitializeInArea(this, 24, 24)
	this.events.MouseReleased = AquaShine.Node.Util.InAreaFunction(this, function(x, y)
		this.userdata.is_checked = not(this.userdata.is_checked)
		if onchange then onchange(this.userdata.is_checked) end
	end)
end

function Checkbox.isChecked(this)
	return this.userdata.is_checked
end

function Checkbox.getPosition(this)
	return this.x, this.y
end

function Checkbox.setPosition(this, x, y)
	if type(x) == "number" then
		this.x = x
	end
	
	if type(y) == "number" then
		this.y = y
	end
	
	return this
end

function Checkbox.setChecked(this, checked)
	this.userdata.is_checked = not(not(checked))
	return this
end

function Checkbox.draw(this)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(this.userdata.checkbox, this.x, this.y)
	
	if this.userdata.is_checked then
		love.graphics.draw(this.userdata.checkbox_check, this.x, this.y)
	end
	
	if #this.actualtext > 0 then
		love.graphics.setColor(this.color)
		love.graphics.draw(this.text, this.x + 33, this.y + 2)
	end
	
	return AquaShine.Node.Colorable.draw(this)
end

return Checkbox
