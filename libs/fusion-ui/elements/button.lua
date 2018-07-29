--[[ Button element ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.button"))
local gui = require(path .. ".dummy")

local button = {}
button.__index = button

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

gui.style.defaultStyle.button = {
	--This means that the text will hover over the center of the origin, rather than
	--drawing from it
	alignToCenter = false,

	elementIndex = true
}

function button.new(str)
	return setmetatable({
		str = str or 'string missing'
	}, button)
end

function button:cleanUp()
	gui.input.removeBox(self.box)
	self.box = nil
end

function button:update(x, y, w, h, str, style, element)
	local mouse = gui.inputBuffer.mouse

	self.w = w
	self.h = h

	self:getSize(str, style)

	self.str = str

	if not self.box then
		self.box = gui.input.addBox(x, y, self.w, self.h, style.z, 1)
	end

	self.box.w = self.w
	self.box.h = self.h
	self.box.x = x
	self.box.y = y

	local st = state.check(self.box, {
		'pressed', 
		'released', 
		'entered', 
		'exited', 
		'pressEvent', 
		'over',
		'down',
		'dropped',
		'dragged'
	})

	return {
		state = st,

		drawX = x,
		drawY = y,

		w = w,
		h = h,
	}

end

function button:getSize(str, style)
	if not self.w then
		self.w = misc.getWidth(style, style.font:getWidth(str))
	end

	if not self.h then
		self.h = misc.getHeight(style, style.font:getHeight(str))
	end

	return self.w, self.h
end

function button:render(x, y, w, h, str, style)
	--[[local values = {
		x = x,
		y = y,
		w = w,
		h = h,
		fgColor = fgColor,
		bgColor = bgColor,
		acColor = acColor
	}]]

	local values = {
		x = x,
		y = y,
		w = w,
		h = h,

		style = style
	}

	local fH = style.font:getHeight()
	local fW = style.font:getWidth(str)


	values.style:drawBackground(values.x, values.y, values.w, values.h)

	love.graphics.setFont(values.style.font)
	
	love.graphics.setColor(values.style.foregroundColor)

	if style.align == 'left' then
		love.graphics.print(str, values.x+values.style.padding[1], math.floor(values.y+values.h/2-fH/2)+values.style.padding[2])
	elseif style.align == 'right' then
		love.graphics.print(str, values.x+math.floor(values.w-values.style.padding[3]-fW), math.floor(values.y+values.h/2-fH/2)+values.style.padding[2])
	else
		love.graphics.print(str, values.x+math.floor((values.w/2-fW/2)), math.floor(values.y+values.h/2-fH/2)+values.style.padding[2])
	end

	love.graphics.setStencilTest()
end

return button