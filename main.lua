-- DEPLS2 main initialization script
-- Copyright © 2038 Dark Energy Processor

local JSON = require("JSON")
local Yohane = require("Yohane")
DEPLS_VERSION = "20170404"

FontManager = require("font_manager")
LogicalScale = {
	ScreenX = 960,
	ScreenY = 640,
	OffX = 0,
	OffY = 0,
	ScaleOverall = 1
}
CurrentEntry = {}

local loader = {
	livesim = {1, "livesim.lua"},
	settings = {0, "setting_view.lua"},
	main_menu = {0, "main_menu.lua"},
	beatmap_select = {0, "select_beatmap.lua"},
	unit_editor = {0, "unit_editor.lua"},
	about = {0, "about_screen.lua"}
}

local function error_printer(msg, layer)
	print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

local function basename(f)
	local _ = f:reverse()
	return _:sub(1,(_:find("/") or _:find("\\") or #_ + 1) - 1):reverse()
end

--! @brief Load configuration
--! @param config_name The configuration name
--! @param default_value The default value of the configuration
--! @returns Configuration value or `default_value` (and save it as `default_value`)
function LoadConfig(config_name, default_value)
	local file = love.filesystem.newFile(config_name..".txt")
	
	if not(file:open("r")) then
		assert(file:open("w"))
		file:write(tostring(default_value))
		file:close()
		
		return default_value
	end
	
	local data = file:read()
	
	return tonumber(data) or data
end

local skip_val = 0
--! @brief Loads entry point
--! @param name The entry point Lua script file
--! @param arg Additional argument to be passed
function LoadEntryPoint(name, arg)
	local scriptfile = love.filesystem.load(name)
	CurrentEntry = scriptfile()
	CurrentEntry.Start(arg or {})
	
	skip_val = 2
end

--! @brief Translates physical touch position to logical touch position
--! @param x Physical touch x coordinate
--! @param y Physical touch y coordinate
--! @returns Logical x and y coordinate
function CalculateTouchPosition(x, y)
	return
		(x - LogicalScale.OffX) / LogicalScale.ScaleOverall,
		(y - LogicalScale.OffY) / LogicalScale.ScaleOverall
end

local mount_target
--! @brief Mount a zip file, relative to DEPLS save directory.
--!        Unmounts previous mounted zip file, so only one zip file
--!        can be mounted.
--! @param path The Zip file path (or nil to clear)
--! @param target The Zip mount point
--! @returns Previous mounted ZIP filename (or nil if no Zip was mounted)
function MountZip(path, target)
	local prev_mount = mount_target
	
	if path ~= nil and mount_target == path then
		return prev_mount
	end
	
	if mount_target then
		love.filesystem.unmount(mount_target)
		mount_target = nil
	end
	
	if path then
		assert(love.filesystem.mount(path, target))
		
		mount_target = path
	end
	
	return prev_mount
end

-- Yohane initialization
function Yohane.Platform.ResolveImage(path)
	return love.graphics.newImage("image/"..basename(path))
end

function Yohane.Platform.ResolveAudio(path)
	return love.audio.newSource("sound/"..basename(path)..".ogg")
end

function Yohane.Platform.CloneImage(image_handle)
	return image_handle
end

function Yohane.Platform.CloneAudio(audio)
	if audio then
		return audio:clone()
	end
	
	return nil
end

function Yohane.Platform.PlayAudio(audio)
	if audio then
		audio:stop()
		audio:play()
	end
end

function Yohane.Platform.Draw(drawdatalist)
	local r, g, b, a = love.graphics.getColor()
	
	for _, drawdata in ipairs(drawdatalist) do
		local wh = drawdata.image:getWidth() * 0.5
		local hh = drawdata.image:getHeight() * 0.5
		love.graphics.setColor(drawdata.r, drawdata.g, drawdata.b, drawdata.a)
		
		-- Since rotation is first, use push/pop methods
		love.graphics.push()
		love.graphics.translate(drawdata.x + wh, drawdata.y + hh)
		love.graphics.rotate(drawdata.rotation)
		love.graphics.translate(-wh, -hh)
		love.graphics.scale(drawdata.scaleX, drawdata.scaleY)
		love.graphics.draw(drawdata.image)
		love.graphics.pop()
	end
	
	love.graphics.setColor(r, g, b, a)
end

function Yohane.Platform.OpenReadFile(fn)
	local x = assert(love.filesystem.newFile("flash/"..basename(fn), "r"))
	x:seek(0)
	
	return x
end
 
function love.errhand(msg)
	msg = tostring(msg)
 
	error_printer(msg, 2)
 
	if not love.window or not love.graphics or not love.event then
		return
	end
 
	if not love.graphics.isCreated() or not love.window.isOpen() then
		local success, status = pcall(love.window.setMode, 800, 600)
		if not success or not status then
			return
		end
	end
 
	-- Reset state.
	if love.mouse then
		love.mouse.setVisible(true)
		love.mouse.setGrabbed(false)
		love.mouse.setRelativeMode(false)
	end
	if love.joystick then
		-- Stop all joystick vibrations.
		for i,v in ipairs(love.joystick.getJoysticks()) do
			v:setVibration()
		end
	end
	if love.audio then love.audio.stop() end
	love.graphics.reset()
	local font = love.graphics.setNewFont(math.floor(love.window.toPixels(14)))
 
	love.graphics.setBackgroundColor(89, 157, 220)
	love.graphics.setColor(255, 255, 255, 255)
 
	local trace = debug.traceback()
 
	love.graphics.clear(love.graphics.getBackgroundColor())
	love.graphics.origin()
 
	local err = {}
 
	table.insert(err, "DEPLS2 encounter a lua error\n")
	table.insert(err, msg.."\n\n")
 
	for l in string.gmatch(trace, "(.-)\n") do
		if not string.match(l, "boot.lua") then
			l = string.gsub(l, "stack traceback:", "Traceback\n")
			table.insert(err, l)
		end
	end
 
	local p = table.concat(err, "\n")
 
	p = string.gsub(p, "\t", "")
	p = string.gsub(p, "%[string \"(.-)\"%]", "%1")
 
	local function draw()
		local pos = love.window.toPixels(70)
		love.graphics.clear()
		love.graphics.printf(p, pos, pos, love.graphics.getWidth() - pos)
		love.graphics.present()
	end
 
	while true do
		love.event.pump()
 
		for e, a, b, c in love.event.poll() do
			if e == "quit" then
				return
			elseif e == "keypressed" and a == "escape" then
				return
			elseif e == "touchpressed" then
				local buttons = {"Yes", "No"}
				local pressed = love.window.showMessageBox("Quit DEPLS2?", "", buttons)
				if pressed == 1 then
					return
				end
			end
		end
 
		draw()
 
		if love.timer then
			love.timer.sleep(0.1)
		end
	end
 
end

function love.load(argv)
	local os_type = love.system.getOS()
	
	if jit and jit.on and os_type == "Android" then
		jit.on()
	end
	
	io.write("R/W Directory: ", love.filesystem.getSaveDirectory(), "\n")
	Yohane.Init(love.filesystem.load)
	
	if os_type == "Android" then
		-- Since we can't pass arguments to Android intent, we have to use txt
		local x = love.filesystem.newFile("command_line.txt", "r")
		
		if x then
			for line in x:lines() do
				line = line:gsub("[\r|\n]", "")
				
				table.insert(argv, line)
			end
		end
	elseif os_type == "iOS" then
		error("iOS is not supported!")
	end
	
	if love.filesystem.isFused() == false then
		table.remove(argv, 1)
	end
	
	local DesiredWindowSize = {}
	local Fullscreen = false
	
	-- Parse arguments
	for i = #argv, 1, -1 do
		local arg = argv[i]
		local remove_arg = false
		
		if not(arg) then break end
		
		do
			local width = arg:match("/width=(%d+)")
			
			if width then
				DesiredWindowSize[1] = tonumber(width)
				
				remove_arg = true
			end
		end
		
		do
			local height = arg:match("/height=(%d+)")
			
			if height then
				DesiredWindowSize[2] = tonumber(height)
				
				remove_arg = true
			end
		end
		
		if arg == "/fullscreen" then
			Fullscreen = true
			
			remove_arg = true
		end
		
		if remove_arg then
			table.remove(argv, i)
		end
	end
	
	if Fullscreen then
		DesiredWindowSize = {0, 0}
	end
	
	-- Set window resolution
	if DesiredWindowSize[1] or DesiredWindowSize[2] then
		love.window.setMode(DesiredWindowSize[1] or 960, DesiredWindowSize[2] or 640, {
			fullscreen = Fullscreen,
			fullscreentype = "desktop",
			resizable = true
		})
	end
	
	-- Calculate logical scale
	LogicalScale.ScreenX, LogicalScale.ScreenY = love.graphics.getDimensions()
	LogicalScale.ScaleX = LogicalScale.ScreenX / 960
	LogicalScale.ScaleY = LogicalScale.ScreenY / 640
	LogicalScale.ScaleOverall = math.min(LogicalScale.ScaleX, LogicalScale.ScaleY)
	LogicalScale.OffX = (LogicalScale.ScreenX - LogicalScale.ScaleOverall * 960) / 2
	LogicalScale.OffY = (LogicalScale.ScreenY - LogicalScale.ScaleOverall * 640) / 2
	
	local progname = table.remove(argv, 1) or "main_menu"
	
	if loader[progname] then
		if loader[progname][1] == 0 or #argv >= loader[progname][1] then
			LoadEntryPoint(loader[progname][2], argv)
			
			return
		end
	end
	
	function love.draw()
		love.graphics.print([[

Usage: love livesim <module = main_menu> <module options>
Module options:
 - livesim: <beatmap name>
 - setting: none
 - main_menu: none
 - beatmap_select: <default selected beatmap name>
 - unit_editor: none
]], 10)
	end
end

local is_update = true
function love.update(deltaT)
	if skip_val > 0 then
		skip_val = skip_val - 1
		return
	end
	
	if is_update then
		is_update = false
	else
		return
	end
	
	CurrentEntry.Update(deltaT * 1000)
end

function love.draw()
	if skip_val > 0 then
		skip_val = skip_val - 1
		return
	end
	
	if not(is_update) then
		is_update = true
	else
		return
	end
	
	local deltaT = love.timer.getDelta() * 1000
	
	love.graphics.push()
	love.graphics.translate(LogicalScale.OffX, LogicalScale.OffY)
	love.graphics.scale(LogicalScale.ScaleOverall, LogicalScale.ScaleOverall)
	CurrentEntry.Draw(deltaT)
	love.graphics.pop()
end

-- LOVE2D on window resize
function love.resize(w, h)
	LogicalScale.ScreenX, LogicalScale.ScreenY = w, h
	LogicalScale.ScaleX = LogicalScale.ScreenX / 960
	LogicalScale.ScaleY = LogicalScale.ScreenY / 640
	LogicalScale.ScaleOverall = math.min(LogicalScale.ScaleX, LogicalScale.ScaleY)
	LogicalScale.OffX = (LogicalScale.ScreenX - LogicalScale.ScaleOverall * 960) / 2
	LogicalScale.OffY = (LogicalScale.ScreenY - LogicalScale.ScaleOverall * 640) / 2
end

function love.filedropped(file)
	print("File Dropped", file:getFilename())
end

function love.directorydropped(dir)
	print("Dir Dropped", dir)
end

require("touch_manager")
