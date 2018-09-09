-- Slightly modified error handler, based on LOVE 11.0 error handler
-- Part of Live Simulator: 2

local love = require("love")
local color = require("color")
local log = require("logging")
local util = require("util")
local postExit = require("post_exit")
local utf8 = require("utf8")

local function error_printer(msg, layer)
	log.error("errhand", (debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

function love.errorhandler(msg)
	local lily = require("libs.lily")
	local gamestate = require("gamestate")
	local setting = require("setting")

	lily.quit()
	gamestate.internal.quit()
	setting.quit()
	postExit.exit()

	msg = tostring(msg)
	error_printer(msg, 2)
	if not love.window or not love.graphics or not love.event then
		return
	end

	if not love.graphics.isCreated() or not love.window.isOpen() then
		return
	end

	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
		if util.isCursorSupported() then
			love.mouse.setCursor()
		end
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for _,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end

	love.graphics.reset()
	love.graphics.setNewFont(14)

	love.graphics.setColor(color.white)

	local trace = debug.traceback()

	love.graphics.origin()

	local sanitizedmsg = {}
	for char in msg:gmatch(utf8.charpattern) do
		table.insert(sanitizedmsg, char)
	end
	sanitizedmsg = table.concat(sanitizedmsg)

	local err = {}

	table.insert(err, "Error\n")
	table.insert(err, sanitizedmsg)

	if #sanitizedmsg ~= #msg then
		table.insert(err, "Invalid UTF-8 string in error message.")
	end

	table.insert(err, "\n")

	for l in trace:gmatch("(.-)\n") do
		if not l:match("boot.lua") then
			l = l:gsub("stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end

	local p = table.concat(err, "\n")

	p = p:gsub("\t", "")
	p = p:gsub("%[string \"(.-)\"%]", "%1")

	local function draw()
		local pos = 70
		love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
		love.graphics.present()
		love.graphics.clear(color.hex599DDC)
	end

	local fullErrorText = p
	local function copyToClipboard()
		if not love.system then return end
		love.system.setClipboardText(fullErrorText)
		p = p .. "\nCopied to clipboard!"
		--return draw()
	end

	if love.system then
		p = p .. "\n\nPress Ctrl+C or tap to copy this error"
	end

	local step = function()
		love.event.pump()

		for e, a in love.event.poll() do
			if e == "quit" then
				return 1
			elseif e == "keypressed" and a == "escape" then
				return 1
			elseif e == "keypressed" and a == "c" and love.keyboard.isDown("lctrl", "rctrl") then
				copyToClipboard()
			elseif e == "touchpressed" then
				local name = love.window.getTitle()
				if #name == 0 or name == "Untitled" then name = "Game" end
				local buttons = {"OK", "Cancel"}
				if love.system then
					buttons[3] = "Copy to clipboard"
				end
				local pressed = love.window.showMessageBox("Quit "..name.."?", "", buttons)
				if pressed == 1 then
					return 1
				elseif pressed == 3 then
					copyToClipboard()
				end
			end
		end

		draw()
	end

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
love.errhand = love.errorhandler
