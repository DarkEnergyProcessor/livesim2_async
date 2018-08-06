--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.text"))
local gui = require(path .. ".dummy")

---A basic element for displaying text
-- Content is a string
-- Can display multi-line text, which needs to be separated with a \n
-- @module text
local text = {}
text.__index = text

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

gui.style.defaultStyle.text = {
	--This means that the text will hover over the center of the origin, rather than
	--drawing from it
	alignToCenter = false,
	linespacing = 1.1,
}

function text.new(str)
	return setmetatable({
		str = str or 'string missing',
	}, text)
end

function text:cleanUp()
	gui.input.removeBox(self.box)
	self.box = nil
end

function text:update(x, y, overw, overh, str, style, callbacks, element)
	str = str or self.str 
	local origStr = self.str

	if self.first==nil then
		self.first = true
	end
	--String processing

	if origStr ~= str or self.first then
		if str:find('\n') then
			self.multiStr = string.multi(str, style)
			self.h = self.multiStr.h + style.padding[2] + style.padding[4]
			self.w = self.multiStr.maxLn + style.padding[1] + style.padding[3]
		else
			self.h = self.fontH + style.padding[2] + style.padding[4] 
			self.fontW = style.font:getWidth(str)
			self.fontH = style.font:getHeight()
			self.w = self.fontW + style.padding[1] + style.padding[3]
		end
	end
	self.first = false
	self.str = str

	if overw then
		self.w = overw
	end

	if overh then
		self.h = overh
	end

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

		w = self.w,
		h = self.h,
	}

end

function text:getSize(str, style)
	if self.first~=false then
		self.fontH = style.font:getHeight()
		if str:find('\n') then
			self.multiStr = string.multi(str, style)
			self.h = self.multiStr.h + style.padding[2] + style.padding[4]
			self.w = self.multiStr.maxLn + style.padding[1] + style.padding[3]
		else
			self.h = self.fontH + style.padding[2] + style.padding[4] 
			self.fontW = style.font:getWidth(str)
			self.w = self.fontW + style.padding[1] + style.padding[3]
		end
	end

	return self.w, self.h
end

function text:render(x, y, w, h, str, style, animation)
	local values = {
		x = x,
		y = y,
		w = w,
		h = h,

		style = style
	}

	local fH = self.fontH
	local fW = self.fontW

	values.style:drawBackground(values.x, values.y, values.w, values.h)
	
	love.graphics.setColor(values.style.foregroundColor)
	love.graphics.setFont(values.style.font)
	if self.multiStr then
		for i, e in ipairs(self.multiStr) do
			if style.align == 'left' then
				love.graphics.draw(e.str, values.x+values.style.padding[1], values.y+values.style.padding[2]+math.ceil((i-1)*fH*values.style.text.linespacing))
			elseif style.align == 'center' then
				love.graphics.draw(e.str, values.x+math.floor((values.w/2-e.w/2)), values.y+values.style.padding[2]+math.ceil((i-1)*fH*values.style.text.linespacing))
			else
				love.graphics.draw(e.str, values.x+math.floor(values.w-values.style.padding[3]-e.w), values.y+values.style.padding[2]+math.ceil((i-1)*fH*values.style.text.linespacing))
			end
		end
	else
		if style.align == 'left' then
			love.graphics.print(self.str, values.x+values.style.padding[1], math.floor(values.y+values.h/2-fH/2)+values.style.padding[2])
		elseif style.align == 'center' then
			love.graphics.print(self.str, values.x+math.floor((values.w/2-fW/2)), math.floor(values.y+values.h/2-fH/2)+values.style.padding[2])
		else
			love.graphics.print(self.str, values.x+math.floor(values.w-values.style.padding[3]-fW), math.floor(values.y+values.h/2-fH/2)+values.style.padding[2])
		end
	end
	
	love.graphics.setStencilTest()
end

return text