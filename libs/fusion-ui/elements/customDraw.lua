--[[ Custom draw element ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.customDraw"))
local gui = require(path .. ".dummy")

local customDraw = {}
customDraw.__index = customDraw

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

--[[an element type where the user can insert custom draw, update functions
content is {
    update = function(x, y, w, h, style, elem, states) return {customState} end,
    draw = function(x, y, w, h, customState, style) end,
    getSize = function(style) end,
}
]]
function customDraw.new(content)
	return setmetatable({
		content = content,
	}, customDraw)
end

function customDraw:cleanUp()
	gui.input.removeBox(self.box)
	self.box = nil
end

function customDraw:update(x, y, w, h, content, style, elem)
	self.w = w
	self.h = h

	self:getSize(content, style)
	
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
    
    if self.content.update then
        self.customState = self.content.update(x, y, w, h, style, elem, st, self.customState)
    end
	
	return {
		state = st,
		drawX = x,
		drawY = y,

		content = self.content,

		static = false,

		w = self.w,
		h = self.h
	}
end

function customDraw:getSize(content, style)
	return 20, 20
end

function customDraw:render(x, y, w, h, content, style)
	style:drawBackground(x, y, w, h)

    if self.content.draw then
        self.content.draw(x, y, w, h, self.customState, style)
    end

	gui.platform.setStencilTest()
end

return customDraw