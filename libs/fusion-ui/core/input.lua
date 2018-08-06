--[[ Input module ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".core.input"))
local gui = require(path .. ".dummy")

gui.inputBuffer = {
	mouse = {
		current = {
			x = 1,
			y = 1,
			down = false
		},
		previous = {
			 x = 1,
			y = 1,
			down = false,
		},
		pressEvent = nil,
	},
	keyboard = {
		currentCapture = nil,

		intxt = nil,
		key = nil
	}
}

gui.eventHandlers={}

gui.input = {}

gui.mouseBoxes = {}

--[[ Event handlers, to interface with Loves internal event system ]]

function gui.eventHandlers.keypressed(key)
	if not gui.inputBuffer.keyboard.currentCapture then
		return false
	else
		gui.inputBuffer.keyboard.key = key
		gui.inputBuffer.keyboard.keyTime = love.timer.getTime()

		return true
	end
end

function gui.eventHandlers.keyreleased(key)
	if not gui.inputBuffer.keyboard.currentCapture then
		return false
	else
		gui.inputBuffer.keyboard.keyReleased = key
		--gui.inputBuffer.keyboard.keyTotalTime = love.timer.getTime()-gui.inputBuffer.keyboard.keyTime
		--gui.inputBuffer.keyboard.keyDown = nil
		--gui.inputBuffer.keyboard.keyTime = nil

		return true
	end
end

function gui.eventHandlers.textinput(text)
	if not gui.inputBuffer.keyboard.currentCapture then
		return false
	else
		if not gui.inputBuffer.keyboard.intxt then
			gui.inputBuffer.keyboard.intxt = text
		else
			gui.inputBuffer.keyboard.intxt = gui.inputBuffer.keyboard.intxt..text
		end
		return true
	end
end

function gui.eventHandlers.mousepressed(x, y, button, touch)
	if touch then
		return false
	end

	local t, i = gui.input.checkBoxes(x, y, button)

	if i then
		gui.mouseBoxes[i]['pressed']={x = x, y = y, button = button, touch = touch, time = love.timer.getTime()}
		gui.inputBuffer.mouse.pressEvent = {x = x, y = y, button = button, touch = touch, startBox = gui.mouseBoxes[i]}
	end

	return t
end

function gui.eventHandlers.mousereleased(x, y, button, touch)
	if touch then
		return false
	end

	local t, i = gui.input.checkBoxes(x, y, button)

	if gui.inputBuffer.mouse.pressEvent then
		gui.inputBuffer.mouse.pressEvent.startBox.released = {x = x, y = y, button = button, time = love.timer.getTime()}

		if i then
			gui.mouseBoxes[i]['dropped']={x = x, y = y, button = button, time = love.timer.getTime(), box = gui.inputBuffer.mouse.pressEvent.startBox}
		end


		gui.inputBuffer.mouse.pressEvent.startBox.pressed = nil
		gui.inputBuffer.mouse.pressEvent = nil
	end

	return t
end

function gui.eventHandlers.mousemoved(x, y, dx, dy, touch)
	local t, i
	if touch then
		return false
	end

	if gui.inputBuffer.mouse.pressEvent then
		t, i = gui.input.checkBoxes(x, y, 1)
		gui.inputBuffer.mouse.pressEvent.startBox.dragged = {x = x, y = y, dx = dx, dy = dy, time = love.timer.getTime()}

		if i then
			if gui.inputBuffer.mouse.pressEvent.startBox == gui.mouseBoxes[i] then
				gui.mouseBoxes[i]['elemHover']={x = x, y = y, time = love.timer.getTime()}
				gui.mouseBoxes[i]['pressed']=nil
			end
		end
	end

	return t
end

function gui.eventHandlers.mousePos(x, y)
	gui.inputBuffer.mouse.previous = {x = gui.inputBuffer.mouse.current.x, y = gui.inputBuffer.mouse.current.y}
	gui.inputBuffer.mouse.current = {
		x = x,
		y = y
	}
end

function gui.eventHandlers.touchpressed(id, x, y)
	local t, i = gui.input.checkBoxes(x, y, button)


end

function gui.eventHandlers.touchmoved(id, x, y)
	local t, i = gui.input.checkBoxes(x, y, button)
end

function gui.eventHandlers.touchreleased(id, x, y)
	local t, i = gui.input.checkBoxes(x, y, button)
end

-- [[ Internal utility functions used by the box mouse&touch system ]]

function gui.input.checkBoxes(x, y, button, touch)
	for i = #gui.mouseBoxes, 1, -1 do
		if gui.input.checkBox(x, y, gui.mouseBoxes[i]) then
			return true, i
		end
	end
	return false
end

function gui.input.checkParent(x, y, button, touch, parent)
	for i = #gui.mouseBoxes, 1, -1 do
		if gui.input.checkBox(x, y, gui.mouseBoxes[i]) then
			return true, i
		end
	end
	
	return false
end

function gui.input.checkBox(x, y, box)
	if x>box.x and x<box.x+box.w and y>box.y and y<box.y+box.h then
		return true
	else
		return false
	end
end

local function zsort(b1, b2)
	if b1.z < b2.z then
		return true
	else
		return false
	end
end

local boxParentStack = {}
local boxParent = false

function gui.input.addBox(x, y, w, h, z, button, parent, checkFunc, element)
	local box = {
		x = x, 
		y = y,
		z = z or 1,
		w = w,
		h = h,
		element = element,
		button = button or '1',
		parent = parent or false,
		checkFunc = checkFunc or function() return true end
	}

	box.index = tostring(box)

	if parent then
		box.children = {}
		boxParent = true
		table.insert(boxParentStack, box)
	end

	if boxParent then
		boxParentStack[#boxParentStack].child = box
	else
		--See if the last box has a smaller z than the box being inserted
		if #gui.mouseBoxes>=1 and gui.mouseBoxes[#gui.mouseBoxes].z <= z then
			table.insert(gui.mouseBoxes, box)
		--See if the first box has a larger z than the box being inserted
		elseif #gui.mouseBoxes>1 and gui.mouseBoxes[1].z >= z then
			table.insert(gui.mouseBoxes, 1, box)
		--As last resort insert in the table, then sort
		else
			table.insert(gui.mouseBoxes, box)

			table.sort(gui.mouseBoxes, zsort)
		end
	end
	return box
end

function gui.input.closeParent()
	boxParentStack[#boxParentStack] = nil
	if #boxParentStack < 1 then
		boxParent = false
	end
end

function gui.input.removeBox(box)
	if box then
		for i, e in ipairs(gui.mouseBoxes) do
			if e.index == box.index then
				table.remove(gui.mouseBoxes, i)
				return true
			end
		end
	end
	return false
end

function gui.isInRectangle(xM,yM,xR,yR,w,h)
	if xM>xR and xM<xR+w and yM>yR and yM<yR+h then
		return true
	else
		return false
	end
end