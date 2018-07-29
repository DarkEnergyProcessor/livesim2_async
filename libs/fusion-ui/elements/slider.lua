--[[ Slider element ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.slider"))
local gui = require(path .. ".dummy")

---The Slider element, used for selecting from a gradient of numbers
-- Automatically determines if it's horizontal or vertical
-- Special event: 'changed', { value }
--[[
content = {
		min = 0,
		max = 100,
		step = 10,
		current = 50
	}
]]
--@module slider
local slider = {}
slider.__index = slider

local function round(num, numDecimalPlaces)
	local mult = 10^(numDecimalPlaces or 0)
	return math.floor(num * mult + 0.5) / mult
  end

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

gui.style.defaultStyle.slider = {
	handleColor = {255, 255, 255, 255},
	fillIndicator = {255, 0, 0, 0}
}

--[[properties:
{
	min = 0
	max = 100
	step = 10
	current = 50
}
]]

function slider.new(properties)
	if properties~=nil and type(properties)=='table'then
		return setmetatable({
			min = properties.min or 0,
			max = properties.max or 100,
			step = properties.step or 1,
			current = properties.current or 50,
		}, slider)
	else
		return setmetatable({
			min = 0,
			max = 100,
			step = 10,
			current = 50,
		}, slider)
	end
end

function slider:cleanUp()
	gui.input.removeBox(self.box)
	self.box=nil
end

function slider:update(x, y, w, h, properties, style, elem)
	local mouse = gui.inputBuffer.mouse

	self.w = w
	self.h = h

	self:getSize(properties, style)
	
	if self.w>self.h then
		self.orientation = 'horizontal'
	else
		self.orientation = 'vertical'
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
	
	if st.pressEvent then
		if self.orientation == 'horizontal' then
			self.current = round((((st.pressEvent.x-x)/w)*(self.max-self.min)+self.min)/self.step)*self.step
		else
			self.current =  round((((st.pressEvent.y-y)/h)*(self.max-self.min)+self.min)/self.step)*self.step
		end

		if self.current < self.min then
			self.current = self.min
		end

		if self.current > self.max then
			self.current = self.max
		end

		elem:emitEvent('changed', { value = self.current })
	end


	return {
		state = st,

		drawX = x,
		drawY = y,
		
		content = properties,
		
		static = false,

		w = w,
		h = h,
	}

end

function slider:getSize(str, style)
	return 200, 20
end

function slider:render(x, y, w, h, str, style, animation)
	style:drawBackground(x, y, w, h)

	love.graphics.setColor(style.slider.fillIndicator)
	if self.orientation == 'horizontal' then
		love.graphics.rectangle('fill', x, y+5, w*(self.current/(self.max-self.min)), h-10)
	else
		love.graphics.rectangle('fill', x+5, y, w-10, h*(self.current/(self.max-self.min)))
	end

	love.graphics.setColor(style.slider.handleColor)
	if self.orientation == 'horizontal' then
		love.graphics.rectangle('fill', x-h/2+5+w*(self.current/(self.max-self.min)), y+5, h-10, h-10)
	else
		love.graphics.rectangle('fill', x+5, y-w/2+h*(self.current/(self.max-self.min)), w-10, w-10)
	end

	love.graphics.setStencilTest()
end

return slider