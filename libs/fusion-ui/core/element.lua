--[[ Element module ]]
--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".core.element"))
local gui = require(path .. ".dummy")

---This is the element object, it is used to interact, create with various element types
--@module element
local element = {
	elementBuffer = {},
	renderQueue = {}
}
element.__index = element

---The function used to update all elements present in the buffer
--@param dt Downtime
function element.bufferUpdate(dt)
	local finBuffer = {}

	for index, elem in ipairs(element.elementBuffer) do
		elem:update(dt)

		if elem.persist then
			table.insert(finBuffer,elem)
		end
	end
	element.elementBuffer = finBuffer

	gui.timing.start('bufferUpdate lazy renderer')
	local lr = love.timer.getTime()
	local lrIndex = #element.renderQueue
	--lazy renderer
	for i = #element.renderQueue,1,-1 do
		if love.timer.getTime()-lr<1/120 then
			element.renderQueue[i]:reRender()

			table.remove(element.renderQueue, i)
		else
			return
		end
	end
	gui.timing.stop('bufferUpdate lazy renderer')
end

---Creates a new element
--@param type The type of element to create (string)
--@param content The content of the element (varies by element)
--@param style The style which the element will use
--@return Returns the finished element
function element.newElement(type, content, style)
	local elem = setmetatable({
		type = gui[type].new(content),
		typeName = type,
		masterStyle = gui.style.newStyle(style),
		content = content,
		eventListeners = {},
		event = {},
		canvasColor = {255, 255, 255, 255},
		xoffset = 0,
		yoffset = 0,
		hoffset = 0,
		woffset = 0,
		static = true,
		staticCounter = 0,
		staticOffset = love.math.random(0.2,0.4),
		doNotSleep = false
	}, element)

	elem:releaseStyle()
	return elem
end

---Function to render the element to the actual screen
function element:render(x, y)
--    if self.redraw then
--        self:reRender()
--        self:emitEvent('redrawn')
--    end
	if self.cValues then
		x = x or self.cValues.drawX
		y = y or self.cValues.drawY

		local r, g, b, a = self.canvasColor[1], self.canvasColor[2], self.canvasColor[3], self.canvasColor[4]/255
		gui.platform.setColor(r * a, g * a, b * a, 255 * a)
		
		if self.canvas and self.quad then
			gui.platform.draw(self.canvas, self.quad, x, y)
		end
	end
end

---Adds the element to the internal buffer for one update
--Most useful if you need to draw an element as long as something is true
--And don't want to worry about undrawing it
--@param content Used to override the content in the element, for example if a string changes
--@param buffer This can be set to false to 'initiate' an element
function element:draw(x, y, w, h, content, buffer)

	if buffer == nil then
		buffer = true
	end

	self.x = x or self.x
	self.y = y or self.y

	self.w = w or self.w
	self.h = h or self.h
	self.doNotUpdate = false

	self.drawType = 'once'
		
	self.content = content or self.content

	if self.firstDraw == nil then
		self.firstDraw = true
	else
		self.firstDraw = false
	end

	if buffer then
		table.insert(element.elementBuffer, 1, self)
	end
end

---Puts the element in the buffer until you remove it from there
-- Useful for persistent UI elements like a menu button or health
-- @param content set the content to a diffrent value
function element:drawPersistent(x, y, w, h, content)
	self.x = x or self.x
	self.y = y or self.y

	self.w = w or self.w
	self.h = h or self.h

	self.persist = true
	self.doNotUpdate = false

	self.content = content or self.content

	if self.firstDraw == nil then
		self.firstDraw = true
	else
		self.firstDraw = false
	end

	table.insert(element.elementBuffer, 1, self)
end

function element:drawTimed(x, y, w, h, time)

end

---Removes an element from the draw buffer
function element:unDraw()
	self.firstDraw = nil
	self.persist = false
	self.type:cleanUp()
	self.doNotUpdate = true
	self.canvas = nil
	self.prevCValues = nil
	self.cValues = nil
end

---Updates the element (use if you need to update an element outside of a buffer)
--@buffer set to false if you will manually render the element with element:render(x,y)
function element:update(dt, buffer)
	if self.doNotUpdate then
		return
	end

	if buffer == nil and not self.firstDraw==true then
		buffer = true
	end

	if self.style==nil then
		self:releaseStyle()
	end

	if (not self.static) or self.staticCounter > self.staticOffset or self.firstDraw or self.redraw or not self.canvas or self.activeAnimation or self.doNotSleep then

		self.staticCounter = 0

		local r = self.type:update(self.x+self.xoffset, self.y+self.yoffset, self.w+self.woffset, self.h+self.hoffset, self.content, self.style, self)

		if r.static == false then
			self.doNotSleep = true
		end

		if self.cValues then
			self.prevCValues = self.cValues
		end

		self.content = r.content or self.content
	
		self.drawX = r.drawX
		self.drawY = r.drawY

		self.state = r.state

		self.cValues = {
			drawX = r.drawX,
			drawY = r.drawY,

			w = r.w or self.w,
			h = r.h or self.h,
		}
	
		if self.prevCValues and not self.redraw then
			if self.prevCValues.w ~= self.cValues.w or self.prevCValues.h ~= self.cValues.h then
				self.redraw = true
				self:emitEvent('changed')
			else
				self.redraw = false
			end
		else
			self.redraw = true
		end

		self.firstDraw = false

		self:emitEvent('update', dt)
		self:stateEvents()
		self:pulseEvents()

		if self.redraw then
			if not self.inQueue or self.typeName=='frame' then
				table.insert(element.renderQueue, self)
				self.inQueue = true
				self:emitEvent('redrawn')
			end
		end

	else
		self.staticCounter = self.staticCounter+dt
	end

	if buffer then 
		table.insert(gui.gfxBuffer,1, self)
	end
end

---Emits an event to the element, useful to chain animations
--@param eventName The name of the event to emit to
--@param event The data the event transmits, could be nothing, coordinates or something else entirely
function element:emitEvent(eventName, event)
	event = event or {}
	self.event[eventName] = event
end

function element:directEmit(eventName, event)
	if self.eventListeners[eventName] then
		for i, e in ipairs(self.eventListeners[eventName]) do
			
		end
	end
end

---Adds an event listener to a specific event name
--Use this to capture mouse, keyboard and animation finish events
--@param eventName The name of the event to listen for
--@param func The function to call, when the event is detected
--@param obj If you need to call a method, for example obj:func()
function element:addEventListener(eventName, func, obj, id)
	if not self.eventListeners[eventName] then
		self.eventListeners[eventName]={}
	end

	if not id then
		self.static = false
		self.doNotSleep = true
	end

	table.insert(self.eventListeners[eventName], {func = func, obj = obj, id = id })
end

---Template for a basic listener function
--@param event The event data
--@param element The element that called this function
--@param index The index of this listener, for use with :removeEventListener(eventName, index)
local function listener_func(event, element, index)
end

function element:stateEvents()
	local state = self.state

	for i, e in pairs(state) do
		self.event[i] = e
	end
end

function element:pulseEvents()
	self.prevEvents = self.event
	self.event = {}

	for eventName, event in pairs(self.prevEvents) do
		if self.eventListeners[eventName] then
			for listIndex, listener in pairs(self.eventListeners[eventName]) do
				if listener.obj then
					listener.func(listener.obj,event, self, listIndex, listener.id)
				else
					listener.func(event, self, listIndex, listener.id)
				end
			end 
		end
		
		if eventName == 'changed' or eventName == 'styleswitch' or eventName == 'stylechange' then
			self.redraw = true
			self.static = false
		elseif not self.doNotSleep then
			self.static = true
			self.staticCounter = 0
		end
	end

end

---For use inside a eventListener function
function element:removeEventListener(eventName, index)
	if self.eventListeners[eventName] and self.eventListeners[eventName][index] then
		table.remove(self.eventListeners[eventName], index)
	end
end

--[[Element sleep manager]]
function element:manageSleep()

end

--[[Element property manager]]
function element:manageProperties()

end

function element:lockStyle()
	self.lockedStyle = true
end

function element:unlockStyle()
	self.lockedStyle = false
end

function element:styleOverride(style, priority)
	local index = tostring(love.timer.getTime())
	if self.lockedStyle then
		return index
	end
	priority = priority or 1

	if self.styleBuffer == nil then
		self.styleBuffer = {}
		self.stylePriority = 0
	end

	table.insert(self.styleBuffer,{style = style, index = index, priority = priority})

	if self.stylePriority<=priority then
		self.currentStyleIndex = index

		self.stylePriority = priority

		self.style = style
		self:emitEvent('stylechange')

		self.redraw = true
	end

	return index
end

function element:releaseStyle(index)
	if self.lockedStyle then
		return
	end
	self.redraw = true

	if (self.styleBuffer and #self.styleBuffer == 1) or not self.styleBuffer then
		self.style = setmetatable({},{
			__index = function (t, index)
				return self.masterStyle[index]
			end,
			__newindex = function (t, index, val)
				self:emitEvent('stylechange',{})
				self.masterStyle[index] = val
			end
		} )
		self.styleBuffer = nil
		self.stylePriority = 0
	else

		for i, e in ipairs(self.styleBuffer) do
			if e.index == index then
				table.remove(self.styleBuffer, i)

				if self.currentStyleIndex == index then
					self.style = self.styleBuffer[#self.styleBuffer].style
					self.currentStyleIndex = self.styleBuffer[#self.styleBuffer].index
					self.stylePriority = self.styleBuffer[#self.styleBuffer].priority
					self:emitEvent('stylechange',{})
				end
				return true
			end
		end        

		return false
	end

end

function element:getSize()
	return self.type:getSize(self.content, self.style)
end

function element:reRender()
	if self.cValues then
	if not self.canvas then
		self.canvasSize = {
			w = math.ceil((self.w-self.woffset)*1.5),
			h = math.ceil((self.h-self.hoffset)*1.5)
		}

		self.canvas = gui.platform.newCanvas(self.canvasSize.w, self.canvasSize.h)
		self:emitEvent('canvasinit',{canvas = self.canvas})
	end

	gui.platform.setCanvas(self.canvas)
	
	gui.platform.clear()


	self.type:render(0, 0, self.cValues.w, self.cValues.h, self.content, self.style)


	gui.platform.setCanvas()
	if not self.quad then
		self.quad = love.graphics.newQuad(0,0,self.cValues.w, self.cValues.h, self.canvasSize.w, self.canvasSize.h )
	else
		self.quad:setViewport(0, 0, self.cValues.w, self.cValues.h)
	end

	self:emitEvent('redrawn',{})
	self.staticCounter=1
	self.redraw = false
	self.inQueue = false
	end
end

function element:attach(element, direction, offset)

end

return element