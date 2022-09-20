-- Game main loop
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Vires = require("vires")
local log = require("logging")
local PostExit = require("post_exit")
local timer = require("libs.hump.timer")
local Util = require("util")
local color = require("color")

--------------------------------
-- LOVE 11.0 argument parsing --
--------------------------------

if love.getVersion() < 11 then

love.arg.options = {
	console = { a = 0 },
	fused = {a = 0 },
	game = {a = 1 }
}
love.arg.optionIndices = {}

-- Finds the key in the table with the lowest integral index. The lowest
-- will typically the executable, for instance "lua5.1.exe".
function love.arg.getLow(a)
	local m = math.huge
	for k,_ in pairs(a) do
		if k < m then
			m = k
		end
	end
	return a[m], m
end

function love.arg.parseOption(m, i)
	m.set = true

	if m.a > 0 then
		m.arg = {}
		for j=i,i+m.a-1 do
			love.arg.optionIndices[j] = true
			table.insert(m.arg, arg[j])
		end
	end

	return m.a
end

function love.arg.parseOptions(arg)
	local game
	local argc = #arg

	local i = 1
	while i <= argc do
		-- Look for options.
		local m = arg[i]:match("^%-%-(.*)")

		if m and m ~= "" and love.arg.options[m] and not love.arg.options[m].set then
			love.arg.optionIndices[i] = true
			i = i + love.arg.parseOption(love.arg.options[m], i+1)
		elseif m == "" then -- handle '--' as an option
			love.arg.optionIndices[i] = true
			if not game then -- handle '--' followed by game name
				game = i + 1
			end
			break
		elseif not game then
			game = i
		end
		i = i + 1
	end

	if not love.arg.options.game.set then
		love.arg.parseOption(love.arg.options.game, game or 0)
	end

	if love.filesystem.isFused() and not(love.arg.options.fused.set) and game then
		-- really fused
		love.arg.optionIndices[game] = false
	end
end

-- Returns the arguments that are passed to your game via love.load()
-- arguments that were parsed as options are skipped.
function love.arg.parseGameArguments(a)
	local out = {}

	local _, lowindex = love.arg.getLow(a)

	local o = lowindex
	for i=lowindex, #a do
		if not love.arg.optionIndices[i] then
			out[o] = a[i]
			o = o + 1
		end
	end

	return out
end

-- LOVE 0.10.0 backward compatibility
love.arg.parse_option = love.arg.parseOption
love.arg.parse_options = love.arg.parseOptions

end -- love.getVersion() < 11

-------------------
-- Debug Display --
-------------------

local getDebugDisplayText

if Util.compareLOVEVersion(12, 0) >= 0 then
	function getDebugDisplayText(dt, stats)
		return string.format([[
%d FPS (%.2fms update)
LOVE %s: %s
DRAWCALLS = %d (BATCHED %d)
LUAMEMORY = %.2f MB
TEXTUREMEMORY = %d Bytes
LOADED_TEXTURES = %d
CANVAS_SWITCHES = %d
LOADED_FONTS = %d]],
			love.timer.getFPS(),
			dt*1000,
			love._version,
			love._version_codename,
			stats.drawcalls,
			stats.drawcallsbatched,
			collectgarbage("count") / 1024,
			stats.texturememory,
			stats.textures,
			stats.canvasswitches,
			stats.fonts
		)
	end
else
	local hasBatch = Util.compareLOVEVersion(11, 0) >= 0

	function getDebugDisplayText(dt, stats)
		local batchstr = "NO AUTOBATCH"

		if hasBatch then
			batchstr = string.format("BATCHED %d", stats.drawcallsbatched)
		end

		return string.format([[
%d FPS (%.2fms update)
LOVE %s: %s
DRAWCALLS = %d (%s)
LUAMEMORY = %.2f MB
TEXTUREMEMORY = %d Bytes
LOADED_IMAGES = %d
LOADED_CANVAS = %d (SWITCHES = %d)
LOADED_FONTS = %d]],
			love.timer.getFPS(),
			dt*1000,
			love._version,
			love._version_codename,
			stats.drawcalls,
			batchstr,
			collectgarbage("count") / 1024,
			stats.texturememory,
			stats.images,
			stats.canvases,
			stats.canvasswitches,
			stats.fonts
		)
	end
end

---------------
-- Game loop --
---------------

--[[
local u = print
function print(...)
	u(...)
	u(debug.traceback())
end
]]

function love.run()
	-- At least LOVE 0.10.0 (must be checked here, otherwise window will show up)
	assert(love._version >= "0.10.0", "minimum LOVE version needed is LOVE 0.10.0")
	-- We have to delay-load any script that depends on Lily
	-- because Lily checks the loaded library
	-- and doesn't require them.
	local Async = require("async")
	local lily = require("lily")
	local Gamestate = require("gamestate")
	-- delay-load setting library also
	local Setting = require("setting")
	-- screenshot depends on love.graphics
	local screenshot = require("screenshot")
	-- reparse it because we lose it in above code
	love.arg.parseOptions(arg)
	-- Now we have LOVE 11.0 behaviour for argument parsing
	if love.load then love.load(love.arg.parseGameArguments(arg), arg) end

	-- debug info code
	local showDebugInfo = log.getLevel() >= 4
	local defaultText

	-- Only load UI if window is present, also it must be after
	-- love.load, because love.load may initialize window.
	local Glow
	if love.window.isOpen() then
		Glow = require("game.afterglow")
		defaultText = love.graphics.newText(love.graphics.newFont(20))
	end

	-- Register post exit
	PostExit.add(Gamestate.internal.quit)
	PostExit.add(lily.quit)
	PostExit.add(Setting.quit)
	-- We don't want the first frame's dt to include time taken by love.load.
	love.timer.step()

	-- We create step function in here
	-- for portability code path you can see below.
	local function step()
		-- Update dt, as we'll be passing it to update
		love.timer.step()
		local dt = love.timer.getDelta()
		Gamestate.internal.loop()
		timer.update(dt)
		Async.loop(dt)
		-- Process events.
		love.event.pump()
		for name, a, b, c, d, e, f, g, h, i, j in love.event.poll() do
			-- update virtual resolution for resize
			if name == "resize" then
				Vires.update(a, b)
			elseif name == "displayrotated" then
				Vires.update(love.graphics.getDimensions())
			-- low memory warning
			elseif name == "lowmemory" then
				collectgarbage()
				collectgarbage()
				if jit then jit.flush() end
			-- modify position with virtual resolution
			elseif name == "mousepressed" or name == "mousereleased" or name == "mousemoved" then
				a, b = Vires.screenToLogical(a, b)
				if name == "mousemoved" then
					c, d = c / Vires.data.scaleOverall, d / Vires.data.scaleOverall
				end
			elseif name == "touchpressed" or name == "touchreleased" or name == "touchmoved" then
				b, c = Vires.screenToLogical(b, c)
				d, e = d / Vires.data.scaleOverall, e / Vires.data.scaleOverall
			-- print information (debug). sent from another thread
			--elseif name == "print" then
				--print(a)
			-- update setting on focus triggered
			elseif name == "focus" then
				Setting.update()
			end
			-- Hardcoded "collectgarbage" button
			if name == "keyreleased" then
				log.debugf("run", "keypressed: key=%s scancode=%s", a, b)
				if a == "f9" then
					-- force GC
					collectgarbage()
					collectgarbage()
					if jit then jit.flush() end
					log.info("run", "collectgarbage issued")
					log.infof("run", "current usage: %.2fMB", collectgarbage("count")/1024)
				elseif a == "f10" then
					if love.keyboard.isDown("lshift", "rshift") then
						-- restart window in case the window freeze
						log.debug("run", "restarting window")
						love.window.setMode(love.window.getMode())
					else
						-- debug info
						showDebugInfo = not(showDebugInfo)
					end
				elseif a == "f12" then
					-- screenshot
					local ssName = string.format("screenshots/screenshot_%s_%d.png",
						os.date("%Y_%m_%d_%H_%M_%S"),
						math.floor((love.timer.getTime() % 1) * 1000)
					)
					love.graphics.captureScreenshot(ssName)
				end
			elseif name == "keypressed" then
				if a == "return" and love.keyboard.isDown("lalt") then
					love.window.setFullscreen(not(love.window.getFullscreen()))
				end
			end
			-- Error on thread error
			assert(name ~= "threaderror", b)

			-- Have to quit all instance in here
			if name == "quit" then
				Gamestate.internal.quit()
				lily.quit()
				Setting.quit()
				PostExit.exit()
				return a or 0
			-- prioritize love.handlers
			elseif love.handlers[name] then
				love.handlers[name](a, b, c, d, e, f, g, h, i, j)
			elseif not(Glow) or not(Glow.handleEvents(name, a, b, c, d, e, f, g, h, i, j)) then
				Gamestate.internal.handleEvents(name, a, b, c, d, e, f, g, h, i, j)
			end
		end

		local currentGame = Gamestate.internal.getActive()
		-- Call update and draw
		if currentGame then currentGame:update(dt) end
		if Glow then Glow.update(dt) end

		if love.graphics and love.graphics.isActive() then
			love.graphics.push("all")
			Vires.set()
			if currentGame then currentGame:draw() end
			if showDebugInfo then
				local stats = love.graphics.getStats()
				defaultText:clear()
				Util.addTextWithShadow(defaultText, getDebugDisplayText(dt, stats), 0, 0, 0.7)
				love.graphics.setColor(color.white)
				love.graphics.draw(defaultText)
			end
			Vires.unset()
			love.graphics.pop()
			screenshot.update() -- slime: call love.graphics.newScreenshot just before love.graphics.present
			love.graphics.present()
			love.graphics.clear() -- some implementation optimize this just after "present"
		end
	end

	-- Portability code
	if love._version >= "11.0" then
		return step
	else
		while true do
			local value = step()
			if value ~= nil then
				return value
			end
		end
	end
end
