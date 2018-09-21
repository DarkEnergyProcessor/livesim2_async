--[[ Element building utilities ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]
local path = string.sub(..., 1, string.len(...) - string.len(".core.elementLib"))
local gui = require(path .. ".dummy")

local state = {}
local strings = {}
local draw = {}
local misc = {}

local mouse = gui.inputBuffer.mouse

--[[ State Checks ]]
function state.check(box, states)
	local st = {}

	local isIn = gui.isInRectangle(mouse.current.x, mouse.current.y, box.x, box.y, box.w, box.h)
	local wasIn = gui.isInRectangle(mouse.previous.x, mouse.previous.y, box.x, box.y, box.w, box.h)

	for i, e in ipairs(states) do
		if state[e]~=nil then
			st[e] = state[e](box, isIn, wasIn)
		end
	end

	box.lastUpdate = love.timer.getTime()

	return st
end

function state.pressed(box)
	if box.pressed then
		local b = box.pressed
		box.pressed = nil
		return b
	end

	return nil
end

function state.released(box)
	if box.released then
		local b
		if gui.inputBuffer.mouse.pressEvent then
			b = {x = box.released.x, y = box.released.y, startx = gui.inputBuffer.mouse.pressEvent.x, starty = gui.inputBuffer.mouse.pressEvent.y}
		else
			b = {x = box.released.x, y = box.released.y}
		end
		box.released = nil
		box.pressEvent = nil
		return b
	end

	return nil
end

function state.pressEvent(box)
	if gui.inputBuffer.mouse.pressEvent then
		if gui.inputBuffer.mouse.pressEvent.startBox == box then
			return {startX = gui.inputBuffer.mouse.pressEvent.x, startY = gui.inputBuffer.mouse.pressEvent.y, x = mouse.current.x, y = mouse.current.y}
		end
	end
end

function state.entered(box, isIn, wasIn)
	if isIn and not wasIn then
		local x = mouse.current.x
		local y = mouse.current.y
		
		return {x = x, y = y}
	end

	return nil
end

function state.exited(box, isIn, wasIn)
	if not isIn and wasIn then
		local x = mouse.previous.x
		local y = mouse.previous.y
		
		return {x = x, y = y}
	end

	return nil
end

function state.dropped(box)
	if box.dropped then 
		local _ = {x = box.dropped.x, y = box.dropped.y, elemDropped = box.dropped.box.element }
		box.dropped = nil
		return _
	end


	return nil
end

function state.dragged(box)
	if box.dragged then 
		local _ = {x = box.dragged.x, y = box.dragged.y, dx = box.dragged.dx, dy = box.dragged.dy }
		box.dragged = nil
		return _
	end


	return nil
end

function state.over(box, isIn, wasIn)
	if isIn then
		return {x = mouse.current.x, y = mouse.current.y}
	end

	return nil
end

function state.down(box, isIn, wasIn)
	if isIn and box.pressEvent then
		return {x = mouse.current.x, y = mouse.current.y}
	end
end

--[[ String operations ]]
function string.multi(str, style, w)
	local multiStr = { maxLn = 0 }

	if w then

	else
		local pstr = str
		while pstr:len()>0 do
			local s, e = pstr:find("[^\n]+\n")
			if s then
				s = pstr:sub(s, e):gsub("\n","")
				pstr = pstr:sub(e)
				e = style.font:getWidth(s)
			else
				s = pstr:gsub("\n","")
				pstr = ''
				e = style.font:getWidth(s)
			end

			if e>multiStr.maxLn then
				multiStr.maxLn = e
			end

			s = gui.platform.newText(style.font, s)

			table.insert(multiStr, {str = s, w = e})
		end
		
		multiStr.h = 1*style.font:getHeight()+(#multiStr-1)*style.font:getHeight()*style.text.linespacing

		return multiStr
	end
end

function draw.multistr(str, style, x, y, w, h)

end
--[[ Miscellaneous ]]
function misc.virtCoordinates(style, x, y)
	virtualX = x + style.margins[1]
	virtualY = y + style.margins[2]

	return virtualX, virtualY
end

function misc.getSize(style, contentW, contentH)
	local w = style.padding[1]+style.padding[3]+contentW
	local h = style.padding[2]+style.padding[4]+contentH

	return w, h
end

function misc.getWidth(style, contentW)
	return style.padding[1]+style.padding[3]+contentW
end

function misc.getHeight(style, contentH)
	return style.padding[2]+style.padding[4]+contentH
end

return {
	misc = misc,
	draw = draw,
	string = string,
	state = state
}