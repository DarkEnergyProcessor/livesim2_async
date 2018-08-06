--[[ Checkbox element ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.checkbox"))
local gui = require(path .. ".dummy")

local checkbox = {}
checkbox.__index = checkbox

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

function checkbox.new(state)
	return setmetatable({
		state = state or false,
	}, checkbox)
end

function checkbox:cleanUp()
	gui.input.removeBox(self.box)
	self.box = nil
end

function checkbox:update(x, y, w, h, str, style, elem)
	self.w = w
	self.h = h

	self:getSize(str, style)
	
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

	if st.pressed then
		self.state = not self.state

		elem:emitEvent('changed',{})
	end
	
	return {
		state = st,
		drawX = x,
		drawY = y,

		content = self.state,

		static = false,

		w = self.w,
		h = self.h
	}
end

function checkbox:getSize(str, style)
	return 20, 20
end

function checkbox:render(x, y, w, h, state, style)
	style:drawBackground(x, y, w, h)

	if self.state then
		love.graphics.setColor(style.foregroundColor)
		love.graphics.rectangle('fill',x+3, y+3, w-6, h-6)
	end
	love.graphics.setStencilTest()
end

return checkbox