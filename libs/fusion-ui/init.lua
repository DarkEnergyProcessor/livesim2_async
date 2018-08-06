--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

--[[ Loader module ]]

local path = ...
local gui  = require(path..".dummy")

gui.gfxBuffer = {}
gui.conf = {}

--[[ Library configuration ]]
gui.conf.customRun     = false
gui.conf.touch_enabled = true
gui.conf.utilities = true
gui.conf.timing = false

--[[ Loading core modules ]]
--[[--------------------------------------------------
	Note that elementLib could be considered not core,
	since it doesn't affect functionality, but
	all elements included use it.
----------------------------------------------------]]
require(path..'.core.input')

gui.style       = require(path..'.core.style')
gui.element     = require(path..'.core.element')
gui.elementLib  = require(path..'.core.elementLib')

--[[ Loading utilities ]]
--[[--------------------------------------------------
	These can be disabled if none of the functionality
	is needed or for performance reasons.
----------------------------------------------------]]
if gui.conf.utilities then
	gui.animation   = require(path..'.utilities.animation')
	gui.styleSwitch = require(path..'.utilities.styleSwitch')
	gui.template    = require(path..'.utilities.template') 
end

--[[ Loading elements ]]
gui.button      = require(path..'.elements.button')
gui.frame       = require(path..'.elements.frame') 
gui.image       = require(path..'.elements.image') 
gui.slider      = require(path..'.elements.slider') 
gui.text        = require(path..'.elements.text') 
gui.textBox     = require(path..'.elements.textBox') 
gui.checkbox    = require(path..'.elements.checkbox') 

--[[ External tool for optimization ]]
gui.timing = require(path..'.utilities.timing')

--[[ After-element load finalizations]]
gui.style.finalize()

--[[ Element buffer rendering ]]
function gui.draw()
	while true do
		local e = table.remove(gui.gfxBuffer, 1)
		if e then
			e:render()
		else
			break
		end
	end
end

--[[
	A user doesn't have to use this particular love.run
	
	*.element.bufferUpdate()
	*.draw()

	Need to be called either through love.update and love.draw respectively
	or put in to your custom love.run

	And for inputs to work the love.event part needs to look something like this:
				
	for name, a,b,c,d,e,f in love.event.poll() do
		if name == "quit" then
			if not love.quit or not love.quit() then
				return a
			end
		end

		if not(gui.eventHandlers[name]) or not(gui.eventHandlers[name](a, b, c, d, e, f)) then
			love.handlers[name](a, b, c, d, e, f)
		end
	end
]]
if not gui.conf.customRun then
function love.run()
 
	if love.math then
		love.math.setRandomSeed(os.time())
	end
 
	if love.load then love.load(arg) end
 
	-- We don't want the first frame's dt to include time taken by love.load.
	if love.timer then love.timer.step() end
 
	local dt = 0
 
	-- Main loop time.
	while true do
		-- Process events.
		gui.timing.startPass()
		gui.timing.start('events')
		if love.event then
			love.event.pump()
			for name, a,b,c,d,e,f in love.event.poll() do
				if name == "quit" then
					if not love.quit or not love.quit() then
						return a
					end
				end

				if not(gui.eventHandlers[name]) or not(gui.eventHandlers[name](a, b, c, d, e, f)) then
					love.handlers[name](a, b, c, d, e, f)
				end
			end
		end

		gui.eventHandlers.mousePos(love.mouse.getX(),love.mouse.getY())

		gui.timing.stop('events')
 
		-- Update dt, as we'll be passing it to update
		if love.timer then
			love.timer.step()
			dt = love.timer.getDelta()
		end
 
		-- Call update and draw
		if love.update then love.update(dt) end -- will pass 0 if love.timer is disabled
		gui.timing.start('bufferUpdate')
		gui.element.bufferUpdate(dt)
		gui.timing.stop('bufferUpdate')
 
		if love.graphics and love.graphics.isActive() then
			love.graphics.clear(love.graphics.getBackgroundColor())
			love.graphics.origin()
			gui.timing.start('love.draw')
			if love.draw then love.draw() end
			gui.timing.stop('love.draw')
			gui.timing.start('guiDraw')
			gui.draw()
			gui.timing.stop('guiDraw')
			gui.timing.start('present')
			love.graphics.present()
			gui.timing.stop('present')
		end

		gui.avgtimers = gui.timing.averageTimers()
		gui.timing.endPass()

		if love.timer then love.timer.sleep(0.0001) end
	end
 
end
end

return gui