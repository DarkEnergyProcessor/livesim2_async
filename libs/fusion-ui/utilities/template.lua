--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".utilities.template"))
local gui = require(path .. ".dummy")

---A utility to create a 'template' for elements, use this to add
-- style switches, animations, event listeners to a group elements that look similar
-- but have different content, like main menu buttons
-- @module template
local template = {}
template.__index = template

---Creates a new template
--@param type The type of the elements that you will create with this template
--@param style The style for the elements that will be created
function template.new(type, style)
	return setmetatable({type = type, style = style, eventListeners = {}}, template)
end

---Returns a finished element
--@param content The content of this element
function template:newElement(content)
	local element = gui.element.newElement(self.type, content, self.style)

	--Adding template event listeners
	for i, el in ipairs(self.eventListeners) do
		element:addEventListener(el.eventName, el.func, el.obj)
	end

	if self.styleSwitches then
		for i, sw in ipairs(self.styleSwitches) do
			element:addStyleSwitch(sw.event, sw.releaseEvent, sw.style)
		end
	end

	if self.animations then
		for i, sw in ipairs(self.animations) do
			element:addAnimation(sw.event, sw.func, sw.length)
		end
	end

	return element
end

---Adds an event listener to all elements created from this template
--For instructions see element:addEventListener
function template:addEventListener(eventName, func, obj)
	table.insert(self.eventListeners, {func = func, obj = obj, eventName = eventName })
end

---Adds a styleSwitch to all elements created from this template
--For instructions see styleSwitch
function template:addStyleSwitch(event, releaseEvent, style)
	if not self.styleSwitches then
		self.styleSwitches = {}
	end

	table.insert(self.styleSwitches, {event = event, releaseEvent = releaseEvent, style = style})
end

---Adds an animation to all elements created from this template
--For instructions see animation
function template:addAnimation(event, func, length)
	if not self.animations then
		self.animations = {}
	end

	table.insert(self.animations, {event = event, func = func, length = length})
end

return template