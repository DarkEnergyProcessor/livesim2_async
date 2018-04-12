-- Aquashine loader. Base layer of Live Simulator: 2

--[[---------------------------------------------------------------------------
-- Copyright (c) 2038 Dark Energy Processor Corporation
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to
-- deal in the Software without restriction, including without limitation the
-- rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
-- sell copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
-- IN THE SOFTWARE.
--]]---------------------------------------------------------------------------

local jit = require("jit")
local ffi = require("ffi")
local table = require("table")
local love = require("love")

assert(love._version >= "11.0", "LOVE 0.10.2 and earlier are no longer supported!")

if not(pcall(require, "table.new")) then
	function table.new()
		return {}
	end
end

if not(pcall(require, "table.clear")) then
	function table.clear(a)
		for n, _ in pairs(a) do
			a[n] = nil
		end
	end
end

local weak_table = {__mode = "v"}
local conf = ...
local AquaShine = {
	CurrentEntryPoint = nil,
	AlwaysRunUnfocus = false,
	SleepDisabled = false,

	-- Cache table. Anything inside this table can be cleared at any time when running under low memory
	CacheTable = setmetatable({}, weak_table),
	-- Preload entry points
	PreloadedEntryPoint = {},
	-- LOVE 11.0 (NewLove) or LOVE 0.10.
	-- Always true, since we stop supporting 0.10.2
	NewLove = true
}

local ScreenshotThreadCode = [[
local lt = require("love.timer")
local li = require("love.image")
local arg = ...
local name = string.format("screenshots/screenshot_%s_%d.png",
	os.date("%Y_%m_%d_%H_%M_%S"),
	math.floor((lt.getTime() % 1) * 1000)
)

require("debug").getregistry().ImageData.encode(arg, "png", name)
print("Screenshot saved as", name)
]]

----------------------------------
-- AquaShine Utilities Function --
----------------------------------

--! @brief Calculates touch position to take letterboxing into account
--! @param x Uncalculated X position
--! @param y Uncalculated Y position
--! @returns Calculated X and Y positions (2 values)
function AquaShine.CalculateTouchPosition(x, y)
	if AquaShine.LogicalScale then
		return
			(x - AquaShine.LogicalScale.OffX) / AquaShine.LogicalScale.ScaleOverall,
			(y - AquaShine.LogicalScale.OffY) / AquaShine.LogicalScale.ScaleOverall
	else
		return x, y
	end
end

local mount_target = {}
--! @brief Counted ZIP mounting. Mounts ZIP file
--! @param path The Zip file path
--! @param target The Zip mount point (or nil to unmount)
--! @returns true on success, false on failure
function AquaShine.MountZip(path, target)
	assert(type(path) == "string")

	if target == nil then
		if mount_target[path] then
			mount_target[path] = mount_target[path] - 1

			if mount_target[path] == 0 then
				mount_target[path] = nil
				AquaShine.Log("AquaShine", "Attempt to unmount %s", path)
				assert(love.filesystem.unmount(path), "Unmount failed")
			end

			return true
		else
			return false
		end
	else
		if not(mount_target[path]) then
			local r = love.filesystem.mount(path, target)

			if r then
				mount_target[path] = 1
				AquaShine.Log("AquaShine", "New mount %s", path)
			end

			return r
		else
			mount_target[path] = mount_target[path] + 1
			return true
		end
	end
end

local config_list = {}
--! @brief Parses configuration passed from command line
--!        Configuration passed via "/<key>[=<value=true>]" <key> is case-insensitive.
--!        If multiple <key> is found, only the first one takes effect.
--! @param argv Argument vector
--! @note This function modifies the `argv` table
function AquaShine.ParseCommandLineConfig(argv)
	if love.filesystem.isFused() == false then
		table.remove(argv, 1)
	end

	local arglen = #arg

	for i = arglen, 1, -1 do
		local k, v = arg[i]:match("^%-(%w+)=?(.*)")

		if k and v then
			config_list[k:lower()] = #v == 0 and true or tonumber(v) or v
			table.remove(arg, i)
		end
	end
end

--! @brief Get configuration argument passed from command line
--! @param key The configuration key (case-insensitive)
--! @returns The configuration value or `nil` if it's not set
function AquaShine.GetCommandLineConfig(key)
	return config_list[key:lower()]
end

--! @brief Set configuration
--! @param key The configuration name (case-insensitive)
--! @param val The configuration value
function AquaShine.SaveConfig(key, val)
	local file = assert(love.filesystem.newFile(key:upper()..".txt", "w"))

	file:write(tostring(val))
	file:close()
end

--! @brief Get configuration
--! @param key The configuration name (case-insensitive)
--! @param defval The configuration default value
function AquaShine.LoadConfig(key, defval)
	AquaShine.Log("AquaShine", "LoadConfig %s", key)
	local file = love.filesystem.newFile(key:upper()..".txt")

	if not(file:open("r")) then
		assert(file:open("w"))
		file:write(tostring(defval))
		file:close()

		return defval
	end

	local data = file:read()
	file:close()

	return tonumber(data) or data
end

local TemporaryEntryPoint
--! @brief Loads entry point
--! @param name The entry point Lua script file
--! @param arg Additional argument to be passed
function AquaShine.LoadEntryPoint(name, arg)
	local scriptdata, title

	if AquaShine.SplashData then
		local data = AquaShine.SplashData
		AquaShine.SplashData = nil

		if type(data) == "string" then
			return AquaShine.LoadEntryPoint(data, {name, arg})
		else
			TemporaryEntryPoint = data
			return data.Start({name, arg})
		end
	end

	AquaShine.SleepDisabled = false
	AquaShine.CallingSetWindowTitle = false
	love.window.setDisplaySleepEnabled(true)

	if name:sub(1, 1) == ":" then
		-- Predefined entry point
		if AquaShine.Config.AllowEntryPointPreload then
			scriptdata, title = assert(AquaShine.PreloadedEntryPoint[name:sub(2)], "Entry point not found")(AquaShine)
			assert(scriptdata, "Script doesn't return entry point")
		else
			scriptdata, title = assert(love.filesystem.load(
				assert(AquaShine.Config.Entries[name:sub(2)], "Entry point not found")[2]
			))(AquaShine)
			assert(scriptdata, "Script doesn't return entry point")
		end
	else
		scriptdata, title = assert(love.filesystem.load(name))(AquaShine)
		assert(scriptdata, "Script doesn't return entry point")
	end

	scriptdata.Start(arg or {})
	TemporaryEntryPoint = scriptdata

	if not(AquaShine.CallingSetWindowTitle) then
		if title then
			love.window.setTitle(AquaShine.WindowName .. " - "..title)
		else
			love.window.setTitle(AquaShine.WindowName)
		end
	end

	AquaShine.CallingSetWindowTitle = false
end

--! @brief Set window title
--! @param title The new window title (or nil to reset)
function AquaShine.SetWindowTitle(title)
	AquaShine.CallingSetWindowTitle = true

	if title then
		love.window.setTitle(AquaShine.WindowName .. " - "..title)
	else
		love.window.setTitle(AquaShine.WindowName)
	end
end

--! Function used to replace extension on file
local function substitute_extension(file, ext_without_dot)
	return file:sub(1, ((file:find("%.[^%.]*$")) or #file+1)-1).."."..ext_without_dot
end

--! @brief Load audio
--! @param path The audio path
--! @param noorder Force existing extension?
--! @returns Audio handle or `nil` plus error message on failure
function AquaShine.LoadAudio(path, noorder, type)
	local s, token_image

	if not(noorder) then
		local a = AquaShine.LoadAudio(substitute_extension(path, "wav"), true, type)

		if a == nil then
			a = AquaShine.LoadAudio(substitute_extension(path, "ogg"), true, type)

			if a == nil then
				return AquaShine.LoadAudio(substitute_extension(path, "mp3"), true, type)
			end
		end

		return a
	end

	if type == "decoder" then
		s, token_image = pcall(love.sound.newDecoder, path)

		if s then
			return token_image
		elseif AquaShine.FFmpegExt and AquaShine.FFmpegExt.Native then
			s, token_image = pcall(AquaShine.FFmpegExt.LoadAudioDecoder, path)
			if s then
				return token_image
			end
		end
		return nil, token_image
	end

	s, token_image = pcall(love.sound.newSoundData, path)

	if s == false then
		if AquaShine.FFmpegExt then
			s, token_image = pcall(AquaShine.FFmpegExt, path)

			if s then
				return token_image
			end
		end

		return nil, token_image
	else
		return token_image
	end
end

--! @brief Load video
--! @param path The video path
--! @returns Video handle or `nil` plus error message on failure
--! @note Audio stream doesn't loaded
function AquaShine.LoadVideo(path)
	local s, a

	if AquaShine.FFmpegExt and (path:sub(-4) == ".ogg" or path:sub(-4) == ".ogv") or not(AquaShine.FFmpegExt) then
		AquaShine.Log("AquaShine", "LoadVideo love.graphics.newVideo %s", path)
		s, a = pcall(love.graphics.newVideo, path)

		if s then
			AquaShine.Log("AquaShine", "LoadVideo love.graphics.newVideo %s success", path)
			return a
		end
	end

	-- Possible incompatible format. Load with FFmpegExt if available
	if AquaShine.FFmpegExt then
		AquaShine.Log("AquaShine", "LoadVideo FFmpegExt %s", path)
		s, a = pcall(AquaShine.FFmpegExt.LoadVideo, path)

		if s then
			AquaShine.Log("AquaShine", "LoadVideo FFmpegExt %s success", path)
			return a
		end
	end

	return nil, a
end

--! @brief Creates new image with specificed position from specificed lists of layers
--! @param w Resulted generated image width
--! @param h Resulted generated image height
--! @param layers Lists of love.graphics.* calls in format {love.graphics.*, ...}
--! @param imagedata Returns ImageData instead of Image object?
--! @returns New Image/ImageData object
function AquaShine.ComposeImage(w, h, layers, imagedata)
	local canvas = love.graphics.newCanvas(w, h, {dpiscale = 1})

	love.graphics.push("all")
	love.graphics.setCanvas(canvas)

	for i = 1, #layers do
		table.remove(layers[i], 1)(unpack(layers[i]))
	end

	love.graphics.pop()

	local id = canvas:newImageData()
	if imagedata then
		return id
	else
		return love.graphics.newImage(id)
	end
end

--! @brief Stripes the directory and returns only the filename
function AquaShine.Basename(file)
	if not(file) then return end

	local x = file:reverse()
	return x:sub(1, (x:find("/") or x:find("\\") or #x + 1) - 1):reverse()
end

--! @brief Determines if runs under slow system (mobile devices)
function AquaShine.IsSlowSystem()
	return AquaShine.OperatingSystem == "Android" or AquaShine.OperatingSystem == "iOS"
end

--! @brief Disable screen sleep
--! @note Should be called only in Start function
function AquaShine.DisableSleep()
	-- tail call
	return love.window.setDisplaySleepEnabled(false)
end

--! @brief Disable touch particle effect
--! @note Should be called only in Start function
function AquaShine.DisableTouchEffect()
	if AquaShine.TouchEffect and AquaShine._TempTouchEffect == nil then
		AquaShine._TempTouchEffect, AquaShine.TouchEffect = AquaShine.TouchEffect, nil
	end
end

--! @brief Disable pause when loses focus
--! @param disable Always run even when losing focus (true) or not (false)
--! @note Should be called only in Start function
function AquaShine.RunUnfocused(disable)
	AquaShine.AlwaysRunUnfocus = not(not(disable))
end

--! @brief Gets cached data from cache table, or execute function to load and store in cache
--! @param name The cache name
--! @param onfailfunc Function to execute when cache is not found. The return value of the function
--!                   then stored in cache table and returned
--! @param ... additional data passed to `onfailfunc`
function AquaShine.GetCachedData(name, onfailfunc, ...)
	local val = AquaShine.CacheTable[name]
	AquaShine.Log("AquaShine", "GetCachedData %s", name)

	if val == nil and onfailfunc then
		val = onfailfunc(...)
		AquaShine.Log("AquaShine", "CachedData, created & cached %s", name)
		AquaShine.CacheTable[name] = val
	end

	return val
end

--! @brief Check if current platform is desktop
--! @returns true if current platform is desktop platform, false oherwise
function AquaShine.IsDesktopSystem()
	return
		AquaShine.OperatingSystem == "Windows" or
		AquaShine.OperatingSystem == "Linux" or
		AquaShine.OperatingSystem == "OS X"
end

--! @brief Set touch effect callback
function AquaShine.SetTouchEffectCallback(c)
	assert(c.Update and c.Start and c.Pause and c.Draw and c.SetPosition, "Invalid callback")

	AquaShine.TouchEffect = c
end

-- For module that requires AquaShine parameter to be passed as 1st argument
local modules = {}
function AquaShine.LoadModule(name, ...)
	name = name:gsub("%.", "/")
	local x = modules[name]

	if x == nil then
		local y = {assert(love.filesystem.load(name..".lua"))(AquaShine, ...)}

		if #y == 0 then
			x = {}
		else
			x = {y[1]}
		end

		modules[name] = x
	end

	return x[1]
end

--! @brief Sets the splash screen before loading entry point (for once)
--! @param splash Splash screen Lua file path or table
function AquaShine.SetSplashScreen(file)
	AquaShine.SplashData = file
end

function AquaShine.Log() end

----------------------------
-- AquaShine Font Caching --
----------------------------
local FontList = setmetatable({}, weak_table)

--! @brief Load font
--! @param name The font name
--! @param size The font size
--! @returns Font object or nil on failure
function AquaShine.LoadFont(name, size)
	size = size or 12

	name = name or AquaShine.DefaultFont
	local cache_name = string.format("%s_%d", name or "LOVE default font", size)

	if not(FontList[cache_name]) then
		local s, a

		if name then s, a = pcall(love.graphics.newFont, name or AquaShine.DefaultFont, size)
		else s = true a = love.graphics.newFont(size) end

		if s then
			FontList[cache_name] = a
		else
			return nil, a
		end
	end

	return FontList[cache_name]
end

--! @brief Set default font to be used for AquaShine
--! @param name The font name
--! @returns Previous default font name
function AquaShine.SetDefaultFont(name)
	local a = AquaShine.DefaultFont
	AquaShine.DefaultFont = assert(type(name) == "string") and name
	return a
end

--------------------------------------
-- AquaShine Image Loader & Caching --
--------------------------------------
local LoadedImage = setmetatable({}, {__mode = "v"})

--! @brief Load image without caching
--! @param path The image path
--! @returns Drawable object
function AquaShine.LoadImageNoCache(path)
	assert(path:sub(-4) == ".png", "Only PNG image is supported")
	local x, y = pcall(love.graphics.newImage, path)
	AquaShine.Log("AquaShine", "LoadImageNoCache %s", path)

	if x then
		return y
	end

	return nil, y
end

--! @brief Load image with caching
--! @param ... Paths of images to be loaded
--! @returns Drawable object
function AquaShine.LoadImage(...)
	local out = {...}

	for i = 1, #out do
		local path = out[i]

		if type(path) == "string" then
			local img = LoadedImage[path]

			if not(img) then
				img = AquaShine.LoadImageNoCache(path)
				LoadedImage[path] = img
			end

			out[i] = img
		else
			out[i] = path
		end
	end

	return unpack(out)
end

----------------------------------------------
-- AquaShine Scissor to handle letterboxing --
----------------------------------------------
function AquaShine.SetScissor(x, y, width, height)
	if not(x and y and width and height) then
		return love.graphics.setScissor()
	end

	if AquaShine.LogicalScale then
		return love.graphics.setScissor(
			x * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffX,
			y * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffY,
			width * AquaShine.LogicalScale.ScaleOverall,
			height * AquaShine.LogicalScale.ScaleOverall
		)
	else
		return love.graphics.setScissor(x, y, width, height)
	end
end

function AquaShine.ClearScissor()
	return love.graphics.setScissor()
end

function AquaShine.IntersectScissor(x, y, width, height)
	if AquaShine.LogicalScale then
		return love.graphics.intersectScissor(
			x * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffX,
			y * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffY,
			width * AquaShine.LogicalScale.ScaleOverall,
			height * AquaShine.LogicalScale.ScaleOverall
		)
	else
		return love.grphics.intersectScissor(x, y, width, height)
	end
end

function AquaShine.GetScissor()
	local x, y, w, h = love.graphics.getScissor()
	if not(x and y and w and h) then return end

	if AquaShine.LogicalScale then
		return
			x * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffX,
			y * AquaShine.LogicalScale.ScaleOverall + AquaShine.LogicalScale.OffY,
			w / AquaShine.LogicalScale.ScaleOverall,
			h / AquaShine.LogicalScale.ScaleOverall
	else
		return x, y, w, h
	end
end

------------------------------
-- Other Internal Functions --
------------------------------
local FileDroppedList = table.new(50, 0)
local frameCounter = 0
local accumulateDT = 0

function AquaShine.StepLoop()
	AquaShine.ExitStatus = nil

	-- Switch entry point
	if TemporaryEntryPoint then
		if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Exit then
			AquaShine.CurrentEntryPoint.Exit()
		end

		AquaShine.CurrentEntryPoint = TemporaryEntryPoint
		TemporaryEntryPoint = nil
	end

	-- Process events.
	love.event.pump()
	for name, a, b, c, d, e, f in love.event.poll() do
		if name == "quit" then
			if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Exit then
				AquaShine.CurrentEntryPoint.Exit(true)
			end

			AquaShine.ExitStatus = a or 0
			return AquaShine.ExitStatus
		end

		love.handlers[name](a, b, c, d, e, f)
	end

	if #FileDroppedList > 0 then
		love.filedropped(FileDroppedList)
		table.clear(FileDroppedList)
	end

	-- Update dt, as we'll be passing it to update
	local dt = love.timer.step()

	if love.graphics.isActive() then
		love.graphics.clear()

		do
			love.graphics.setCanvas {AquaShine.MainCanvas, stencil = true}
			love.graphics.clear()

			if AquaShine.CurrentEntryPoint then
				dt = dt * 1000

				AquaShine.CurrentEntryPoint.Update(dt)
				love.graphics.push("all")

				if AquaShine.LogicalScale then
					love.graphics.translate(AquaShine.LogicalScale.OffX, AquaShine.LogicalScale.OffY)
					love.graphics.scale(AquaShine.LogicalScale.ScaleOverall)
					AquaShine.CurrentEntryPoint.Draw(dt)
				else
					AquaShine.CurrentEntryPoint.Draw(dt)
				end

				love.graphics.pop()
				love.graphics.setColor(1, 1, 1)
			else
				love.graphics.setFont(AquaShine.MainFont)
				love.graphics.print("AquaShine loader: No entry point specificed/entry point rejected", 10, 10)
			end
			love.graphics.setCanvas()
		end
		love.graphics.draw(AquaShine.MainCanvas)
		love.graphics.present()
	end
end

------------------------------------
-- AquaShine love.* override code --
------------------------------------
function love.run()
	math.randomseed(os.time())
	if love.math then
		love.math.setRandomSeed(os.time())
	end

	love.load(arg)

	-- We don't want the first frame's dt to include time taken by love.load.
	love.timer.step()

	-- Main loop time.
	AquaShine.MainFont = AquaShine.LoadFont(nil, 14)
	return AquaShine.StepLoop
end

local function error_printer(msg, layer)
	print((debug.traceback("Error: " .. tostring(msg), 1+(layer or 1)):gsub("\n[^\n]+$", "")))
end

-- Inputs
function love.mousepressed(x, y, button, istouch)
	if istouch == true then return end
	x, y = AquaShine.CalculateTouchPosition(x, y)

	if AquaShine.TouchEffect then
		AquaShine.TouchEffect.Start()
		AquaShine.TouchEffect.SetPosition(x, y)
	end

	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.MousePressed then
		AquaShine.CurrentEntryPoint.MousePressed(x, y, button, istouch)
	end
end

function love.mousemoved(x, y, dx, dy, istouch)
	if istouch == true then return end
	x, y = AquaShine.CalculateTouchPosition(x, y)

	if AquaShine.TouchEffect then
		AquaShine.TouchEffect.SetPosition(x, y)
	end

	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.MouseMoved then
		if AquaShine.LogicalScale then
			return AquaShine.CurrentEntryPoint.MouseMoved(
				x, y,
				dx / AquaShine.LogicalScale.ScaleOverall,
				dy / AquaShine.LogicalScale.ScaleOverall,
				istouch
			)
		else
			return AquaShine.CurrentEntryPoint.MouseMoved(x, y, dx, dy, istouch)
		end
	end
end

function love.mousereleased(x, y, button, istouch)
	if istouch == true then return end

	if AquaShine.TouchEffect then
		AquaShine.TouchEffect.Pause()
	end

	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.MouseReleased then
		x, y = AquaShine.CalculateTouchPosition(x, y)
		AquaShine.CurrentEntryPoint.MouseReleased(x, y, button, istouch)
	end
end

function love.touchpressed(id, x, y, _, _, _)
	return love.mousepressed(x, y, 1, id)
end

function love.touchreleased(id, x, y, _, _, _)
	return love.mousereleased(x, y, 1, id)
end

function love.touchmoved(id, x, y, dx, dy)
	return love.mousemoved(x, y, dx, dy, id)
end

function love.keypressed(key, scancode, repeat_bit)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.KeyPressed then
		AquaShine.CurrentEntryPoint.KeyPressed(key, scancode, repeat_bit)
	end
end

function love.keyreleased(key, scancode)
	if key == "f12" and love.thread then
		love.thread.newThread(ScreenshotThreadCode):start(AquaShine.MainCanvas:newImageData())
	elseif key == "f10" then
		AquaShine.Log("AquaShine", "F10: collectgarbage")
		if jit then jit.flush() end
		collectgarbage("collect")
	end

	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.KeyReleased then
		AquaShine.CurrentEntryPoint.KeyReleased(key, scancode)
	end
end

function love.focus(f)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Focus then
		AquaShine.CurrentEntryPoint.Focus(f)
	end
end

-- File/folder drag-drop support
function love.filedropped(file)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.FileDropped then
		AquaShine.CurrentEntryPoint.FileDropped(file)
	end
end

function love.directorydropped(dir)
	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.DirectoryDropped then
		AquaShine.CurrentEntryPoint.DirectoryDropped(dir)
	end
end

-- On thread error
function love.threaderror(_, msg)
	assert(false, msg)
end

-- Letterboxing recalculation
function love.resize(w, h)
	if AquaShine.LogicalScale then
		local lx, ly = AquaShine.Config.Letterboxing.LogicalWidth, AquaShine.Config.Letterboxing.LogicalHeight
		AquaShine.LogicalScale.ScreenX, AquaShine.LogicalScale.ScreenY = w, h
		AquaShine.LogicalScale.ScaleOverall = math.min(
			AquaShine.LogicalScale.ScreenX / lx,
			AquaShine.LogicalScale.ScreenY / ly
		)
		AquaShine.LogicalScale.OffX = (AquaShine.LogicalScale.ScreenX - AquaShine.LogicalScale.ScaleOverall * lx) / 2
		AquaShine.LogicalScale.OffY = (AquaShine.LogicalScale.ScreenY - AquaShine.LogicalScale.ScaleOverall * ly) / 2
	end

	AquaShine.MainCanvas = love.graphics.newCanvas()

	if AquaShine.CurrentEntryPoint and AquaShine.CurrentEntryPoint.Resize then
		AquaShine.CurrentEntryPoint.Resize(w, h)
	end
end

-- When running low memory
love.lowmemory = jit.flush

-- Initialization
function love.load(arg)
	function love.handlers.filedropped(file)
		FileDroppedList[#FileDroppedList + 1] = file
	end

	-- Initialization
	local wx, wy = love.graphics.getDimensions()
	AquaShine.OperatingSystem = love.system.getOS()
	AquaShine.Class = love.filesystem.load("AquaShine/30log.lua")()

	if AquaShine.GetCommandLineConfig("debug") then
		function AquaShine.Log(part, msg, ...)
			if not(part) then
				local info = debug.getinfo(2)

				if info.short_src and info.currentline then
					part = info.short_src..":"..info.currentline
				end
			end

			io.stderr:write("[", part or "unknown", "] ", string.format(msg or "", ...), "\n")
		end
	end

	AquaShine.WindowName = love.window.getTitle()
	AquaShine.RendererInfo = {love.graphics.getRendererInfo()}
	AquaShine.LoadModule("AquaShine.InitExtensions")
	love.resize(wx, wy)

	if jit and AquaShine.GetCommandLineConfig("interpreter") then
		jit.off()
	end

	-- Preload entry points
	if AquaShine.AllowEntryPointPreload then
		for n, v in pairs(AquaShine.Config.Entries) do
			AquaShine.PreloadedEntryPoint[n] = assert(love.filesystem.load(v[2]))
		end
	end

	-- Load entry point
	if arg[1] and AquaShine.Config.Entries[arg[1]] and AquaShine.Config.Entries[arg[1]][1] >= 0 and #arg > AquaShine.Config.Entries[arg[1]][1] then
		local entry = table.remove(arg, 1)

		AquaShine.LoadEntryPoint(AquaShine.Config.Entries[entry][2], arg)
	elseif AquaShine.Config.DefaultEntry then
		AquaShine.LoadEntryPoint(":"..AquaShine.Config.DefaultEntry, arg)
	end
end

function love._getAquaShineHandle()
	return AquaShine
end

-----------------------------------
-- AquaShine config loading code --
-----------------------------------
do
	love.filesystem.setIdentity(conf.LOVE.Identity, true)

	AquaShine.AllowEntryPointPreload = conf.EntryPointPreload
	AquaShine.Config = conf
	conf.Extensions = conf.Extensions or {}

	if conf.Letterboxing then
		AquaShine.LogicalScale = {
			ScreenX = assert(conf.Letterboxing.LogicalWidth),
			ScreenY = assert(conf.Letterboxing.LogicalHeight),
			OffX = 0,
			OffY = 0,
			ScaleOverall = 1
		}
	end
end
AquaShine.ParseCommandLineConfig(assert(rawget(_G, "arg")))

----------------------------
-- High DPI patch Windows --
----------------------------
ffi.cdef [[
int32_t __stdcall SetProcessDpiAwareness(int32_t );
int32_t __stdcall SetProcessDPIAware();
]]

local function enableHighDPI()
	-- Attempt 1: Use Windows 8.1 API
	local Shcore = ffi.load("Shcore")
	local s, setprocessdpiawareness = pcall(function() return Shcore.SetProcessDpiAwareness end)
	if s then
		local r = setprocessdpiawareness(2)
		if r == 0 then return end
		r = setprocessdpiawareness(1)
		if r == 0 then return end
	end

	-- Attempt 2: Use usual WinAPI
	local setprocessdpiaware
	s, setprocessdpiaware = pcall(function() return ffi.C.SetProcessDPIAware end)
	if s then
		setprocessdpiaware()
	end
end

------------------
-- /gles switch --
------------------
local gles = AquaShine.GetCommandLineConfig("gles")
local integrated = AquaShine.GetCommandLineConfig("integrated") or AquaShine.GetCommandLineConfig("igpu")
do
	local setenv_load = function(x) return x.setenv end
	local putenv_load = function(x) return x.SetEnvironmentVariableA end
	ffi.cdef [[
		int setenv(const char *envname, const char *envval, int overwrite);
		int __stdcall SetEnvironmentVariableA(const char* envname, const char* envval);
	]]

	local ss, setenv = pcall(setenv_load, ffi.C)
	local ps, putenv = pcall(putenv_load, ffi.C)

	if ss then
	    if gles then setenv("LOVE_GRAPHICS_USE_OPENGLES", "1", 1) end
	    if integrated then setenv("SHIM_MCCOMPAT", "0x800000000", 1) setenv("DRI_PRIME", "0", 1) end
		-- Always request compatibility profile
		setenv("LOVE_GRAPHICS_USE_GL2", "1", 1)
	elseif ps then
	    if gles then putenv("LOVE_GRAPHICS_USE_OPENGLES", "1") end
	    if integrated then putenv("SHIM_MCCOMPAT", "0x800000000") end
		-- Always request compatibility profile
		putenv("LOVE_GRAPHICS_USE_GL2", "1")
	end

	if love._os == "Windows" then enableHighDPI() end
end

local function gcfgn(n, m)
	return tonumber(AquaShine.GetCommandLineConfig(n)) or m
end

local function gcfgb(n)
	return not(not(AquaShine.GetCommandLineConfig(n)))
end

local function vsync(v)
	return v == true and 1 or 0
end

-----------------------------
-- Check JIT compiler mode --
-----------------------------

-- A note, JIT compiler must be disabled before love.conf so that other
-- LOVE function which uses "fast paths if JIT is on" is not taken.
do
	local defaultJIT = (love._os == "Android" or love._os == "iOS") and "off" or "on"
	local jit_mode = AquaShine.LoadConfig("JIT_COMPILER", defaultJIT)

	if jit_mode == "off" then
		jit.off()
	elseif jit_mode == "on" then
		jit.on()
	end
end

------------------------
-- Configuration file --
------------------------
function love.conf(t)
	t.identity              = assert(conf.LOVE.Identity)
	t.version               = assert(conf.LOVE.Version) > love._version and conf.LOVE.Version or love._version
	t.console               = false
	t.accelerometerjoystick = false
	t.externalstorage       = conf.LOVE.AndroidExternalStorage
	t.gammacorrect          = false

	t.window.title          = assert(conf.LOVE.WindowTitle)
	t.window.icon           = conf.LOVE.WindowIcon
	t.window.width          = gcfgn("width", assert(conf.LOVE.Width))
	t.window.height         = gcfgn("height", assert(conf.LOVE.Height))
	t.window.borderless     = false
	t.window.resizable      = conf.LOVE.Resizable
	t.window.minwidth       = conf.LOVE.MinWidth
	t.window.minheight      = conf.LOVE.MinHeight
	t.window.fullscreen     = love._os == "iOS" or gcfgb("fullscreen")
	t.window.fullscreentype = "desktop"
	t.window.vsync          = vsync(not(gcfgb("novsync")))
	t.window.msaa           = gcfgn("msaa", 0)
	t.window.display        = 1
	t.window.highdpi        = true -- It's always enabled in Android anyway.
	t.window.x              = nil
	t.window.y              = nil

	t.modules.audio         = not(conf.Extensions.DisableAudio)
	t.modules.joystick      = false
	t.modules.physics       = false
	t.modules.sound         = not(conf.Extensions.DisableAudio)
	t.modules.video         = not(conf.Extensions.DisableVideo)
	t.modules.touch         = not(conf.Extensions.NoMultiTouch)
	t.modules.thread        = not(conf.Extensions.DisableThreads)
end

return AquaShine
