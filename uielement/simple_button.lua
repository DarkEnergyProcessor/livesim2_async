-- Simple button UI, can be scaled
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local SimpleButton = AquaShine.Node:extend("Livesim2.SimpleButton")

function SimpleButton.init(this, image, image_se, action, scale)
	scale = scale or 1
	AquaShine.Node.init(this)
	
	this.image = assert(image, "Normal image needed")
	this.image_se = assert(image_se, "Selected image needed")
	this.userdata.targetimage = "image"
	this.userdata.disabled = false
	this.scale = scale
	this.imagewh = {image:getDimensions()}
	
	AquaShine.Node.Util.InitializeInArea(this, this.imagewh[1] * scale, this.imagewh[2] * scale)
	local pressed = AquaShine.Node.Util.InAreaFunction(this, function(x, y)
		this.userdata.targetimage = "image_se"
	end)
	local moved = AquaShine.Node.Util.InAreaFunction(this, function(x, y)
		this.userdata.targetimage = "image"
	end, true)
	local released = AquaShine.Node.Util.InAreaFunction(this, function(x, y)
		if this.userdata.targetimage == "image_se" then
			action()
		end
		
		this.userdata.targetimage = "image"
	end)
	
	this.events.MousePressed = function(x, y, b, t)
		if this.userdata.targetimage ~= "image_di" then
			return pressed(x, y, b, t)
		end
	end
	this.events.MouseMoved = function(x, y, dx, dy, t)
		if this.userdata.targetimage ~= "image_di" then
			return moved(x, y, dx, dy, t)
		end
	end
	this.events.MouseReleased = function(x, y, b, t)
		if this.userdata.targetimage ~= "image_di" then
			return released(x, y, b, t)
		end
	end
end

function SimpleButton.setDisabledImage(this, image_di)
	this.image_di = image_di
	return this
end

function SimpleButton.disable(this)
	this.userdata.targetimage = "image_di"
	this.userdata.disabled = true
	return this
end

function SimpleButton.enable(this)
	this.userdata.targetimage = "image"
	this.userdata.disabled = false
	return this
end

function SimpleButton.isEnabled(this)
	return not(this.userdata.disabled)
end

function SimpleButton.setTextPosition(this, x, y)
	if this.textshadow then
		this.textshadow:setPosition(this.x + x, this.y + y)
	end
	
	return this
end

function SimpleButton.setText(this, text, norel)
	if this.textshadow then
		this.textshadow:setText(text, norel)
	end
	
	return this
end

function SimpleButton.setTextColor(this, r, g, b, a)
	if this.textshadow then
		this.textshadow:setColor(r, g, b, a)
	end
	
	return this
end

function SimpleButton.setTextShadow(this, w, b, ds, norel)
	if this.textshadow then
		this.textshadow:setShadow(w, b, ds, norel)
	end
	
	return this
end

function SimpleButton.initText(this, font, text)
	this.textshadow = TextShadow(font, text, this.x, this.y)
	return this
end

function SimpleButton.removeText(this)
	this.textshadow = nil
	return this
end

function SimpleButton.draw(this)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(this[this.userdata.targetimage] or this.image, this.x, this.y, 0, this.scale)
	
	if this.textshadow then this.textshadow:draw(this) end
	return AquaShine.Node.draw(this)
end

return SimpleButton
