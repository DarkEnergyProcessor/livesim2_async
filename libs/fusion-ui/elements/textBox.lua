--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.textBox"))
local gui = require(path .. ".dummy")

---The text box is a simple text input element
-- Content is the default value
-- events: changed = { str, txtin } (the current string and the last character), captured, uncaptured = { str } (finished string)
-- @module textBox 
local textBox = {}
textBox.__index = textBox
local utf8 = require 'utf8'

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

function textBox.new(start)
	return setmetatable({
		text = start or '',
	}, textBox)
end

function textBox:cleanUp()
	gui.input.removeBox(self.box)
	self.box = nil
end

function textBox:update(x, y, w, h, str, style, elem)
	self.w = w
	self.h = h

	self:getSize(str, style)
	
	if not self.box then
		self.box = gui.input.addBox(x, y, self.w, self.h, style.z, 1)
	end

	self.box.x = x
	self.box.y = y
	self.box.w = self.w
	self.box.h = self.h

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
		self.capID = love.timer.getTime()
		gui.inputBuffer.keyboard.currentCapture = self.capID
		elem:emitEvent('captured',{})
		elem:emitEvent('changed',{})
		self.tick = true
	elseif gui.inputBuffer.mouse.pressed then
		if gui.inputBuffer.keyboard.currentCapture == self.capID then
			gui.inputBuffer.keyboard.currentCapture = nil
			elem:emitEvent('uncaptured',{str = str})
			elem:emitEvent('changed', {})
		end
	end

	if gui.inputBuffer.keyboard.currentCapture == self.capID and self.capID then
		if gui.inputBuffer.keyboard.intxt ~= nil then
			str = str..gui.inputBuffer.keyboard.intxt
			elem:emitEvent('changed',{ str = str, txtin = gui.inputBuffer.keyboard.intxt})
			gui.inputBuffer.keyboard.intxt = nil
		end

		if gui.inputBuffer.keyboard.key == 'backspace' then
			-- get the byte offset to the last UTF-8 character in the string.
			local byteoffset = utf8.offset(str, -1)
 
			if byteoffset then
				-- remove the last UTF-8 character.
				-- string.sub operates on bytes rather than UTF-8 characters, so we couldn't do string.sub(text, 1, -2).
				str = string.sub(str, 1, byteoffset - 1)
				elem:emitEvent('changed', { str = str })
			end
			gui.inputBuffer.keyboard.key = nil
		elseif gui.inputBuffer.keyboard.key == 'return' then
			gui.inputBuffer.keyboard.currentCapture = nil
			elem:emitEvent('uncaptured',{str = str})
			elem:emitEvent('changed',{})
		end
	elseif self.tick then
		self.tick = false
		elem:emitEvent('uncaptured',{})
		elem:emitEvent('changed',{})
	end
	
	return {
		state = st,
		drawX = x,
		drawY = y,

		content = str,

		static = false,

		w = self.w,
		h = self.h
	}
end

function textBox:getSize(str, style)
	if not self.w then
		self.w = misc.getWidth(style, style.font:getWidth(str))+100
	end

	if not self.h then
		self.h = 20 --misc.getHeight(style, style.font:getHeight(str))
	end

	return self.w, self.h
end

function textBox:render(x, y, w, h, str, style)
	local fH = style.font:getHeight()
	local fW = style.font:getWidth(str)

	style:drawBackground(x, y, w, h)

	love.graphics.setFont(style.font)
	
	love.graphics.setColor(style.foregroundColor)
	
	if fW>w then
		love.graphics.print(str, x+(w-fW), math.floor(y+h/2-fH/2))
	else
		love.graphics.print(str, x, math.floor(y+h/2-fH/2))
	end

	if self.tick then
		love.graphics.print('|', x+fW, math.floor(y+h/2-fH/2))
	end

	love.graphics.setStencilTest()
end

return textBox