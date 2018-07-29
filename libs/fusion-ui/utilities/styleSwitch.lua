--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".utilities.styleSwitch"))
local gui = require(path .. ".dummy")

---A utility to switch styles on events (useful if you want a button to get darker
-- on mouse over, for example)
-- @module styleSwitch
local styleSwitch = {}
styleSwitch.__index = styleSwitch

---Adds a styleswitch to an element
--@param event This is the event that triggers the initial switch
--@param releaseEvent The event that releases the style and returns to the previous one
--@param style The style to switch to
function gui.element:addStyleSwitch(event, releaseEvent, style)
	if not style.drawBackground then
		style = gui.style.newStyle(style)
	end
	local sw = styleSwitch.new(self, style)
	self:addEventListener(event, styleSwitch.call, sw)
	self:addEventListener(releaseEvent, styleSwitch.releaseCall, sw)
end

function styleSwitch.new(element, style)
	return setmetatable({masterStyle = element.masterStyle, switchStyle = style, active = false}, styleSwitch)
end

--Initial event to call
function styleSwitch:call( event, caller)  
	if not self.active then
		self.styleIndex = caller:styleOverride(self.switchStyle,1)
		
		self.active = true
	end
end

--Event to release the style
function styleSwitch:releaseCall( event, caller)
	if self.active then
		caller:releaseStyle(self.styleIndex)
		caller:emitEvent('styleswitch')
	end

	self.active = false
end

return styleSwitch