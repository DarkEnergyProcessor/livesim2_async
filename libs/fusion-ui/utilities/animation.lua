--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".utilities.animation"))
local gui = require(path .. ".dummy")

---The animation module can be used to create smooth and interactive
-- animations for UI elements
-- @module animation
local animation = {}
animation.__index = animation

--[[ The default bezier curve interpolation ]]
local bezCurve = love.math.newBezierCurve( {0,1 ,1,1 ,1,0} )

---Add a new animation to an element
-- @param eventName The event for the animation to hook on to
-- @param func The function that will be executed (see animation function)
-- @param length The lenght of time that the animation will run(in seconds)
-- @param interpolation 'linear' or 'bicubic', for smoother animations
function gui.element:addAnimation(eventName, func, length, interpolation)
	interpolation = interpolation or 'bicubic'
	local anim = animation.new(func, length, self, self.masterStyle, eventName, interpolation)
	self:addEventListener(eventName, anim.start, anim)
end

function animation.new(func, length, element, bStyle, eventName, interpolation)
	local anim = setmetatable({
		interpolation = interpolation,
		func = func, 
		eventName = eventName,
		length = length,
		element = element,

		first = true,
		active = false,

		masterStyle = gui.style.copyStyle(bStyle)
	}, animation)

	anim.style = setmetatable({},{
		__index = function (t, index)
			return anim.masterStyle[index]
		end,
		__newindex = function (t, index, val)
			anim.element:emitEvent('stylechange',{})
			anim.masterStyle[index] = val
		end
	} )

	return anim
end

function animation:update(event, _, num)
	if self.remove then
		self.element:removeEventListener('update', num)
		self.element:emitEvent('animationFinish', self.eventName)
		self.element:releaseStyle(self.styleIndex)
		self.element.redraw = true
		self.element.activeAnimation = false
		self.element.animationProgress = 0
		self.active = false
		self.remove = false
		return
	end


	if type(self.length) == 'number' then
		local dt = love.timer.getDelta()

		self.curTime = love.timer.getTime()
		self.time = self.time+dt
		
		if self.time > self.length then
			self.element:removeEventListener('update', num)
			self.element:emitEvent('animationFinish', self.eventName)
			self.element:releaseStyle(self.styleIndex)
			self.element.redraw = true
			self.element.activeAnimation = false
			self.element.animationProgress = 0
			self.active = false
			return
		else
			self.progress = self.time/self.length
			if self.interpolation == 'bicubic' then
				_,self.progress = bezCurve:evaluate(1-self.progress)
			end

			self.func(self.style, self.progress, event, self.element) 
			self.element.redraw = true
		end
		self.element.animationProgress = self.progress
	else
		
	end
end

function animation:start(event, _, num)

	if self.active then
		--self.time = 0
		--self.prevTime = 0
		--self.progress = 0
	else
		self.element:addEventListener('update', animation.update, self)
		self.styleIndex = self.element:styleOverride(self.style, 2)

		self.active = true
		
		if self.element.activeAnimation and self.element.animationProgress then
			self.element.activeAnimation:cleanUp()
			self.time = self.length-(self.element.animationProgress*self.length)
		else
			self.time = 0
		end

		self.prevTime = -1
		self.progress = 0
		self.element.activeAnimation = self
		
		if self.interpolation == 'bicubic' then
			_,self.progress = bezCurve:evaluate(1-self.progress)
		end

		self.func(self.style, self.progress, event, self.element) 
		self.element.redraw = true
	end
end

function animation:cleanUp()
	self.remove = true
end

---This is a template for the function that changes the internal values of elements
--@param style The style field that you will be changing
--@param progress The length of time that an animation will last (in seconds)
--@param event The event that triggered the animation (could be a press event with mouse coordinates)
--@param element The parent element, change the in here values with care
local function animationFunc(style, progress, event, element)
end

return animation