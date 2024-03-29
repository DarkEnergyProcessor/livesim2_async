-- Script-based storyboard
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION
-- luacheck: read_globals DEPLS_VERSION_NUMBER

local love = require("love")
local Luaoop = require("libs.Luaoop")

local AudioManager = require("audio_manager")
local color = require("color")
local log = require("logging")
local MainFont = require("main_font")
local sandbox = require("sandbox")
local Util = require("util")

local baseStoryboard = require("game.storyboard.base")
local luaStoryboard = Luaoop.class("Livesim2.Storyboard.Lua", baseStoryboard)

local function dummy() end
local function zeroret() return 0 end
local function falseret() return false end

-- LOVE 0.10.0 and LOVE 11.0 has some parameter incompatibilities
-- to tell it not to load audio.
local loadVideoOnly, canvas3rdArg
if Util.compareLOVEVersion(11, 0) >= 0 then
	loadVideoOnly = function(path)
		return love.graphics.newVideo(path, {audio = false})
	end
	canvas3rdArg = {format = "normal", dpiscale = 1}
else
	loadVideoOnly = function(path)
		return love.graphics.newVideo(path, false)
	end
	canvas3rdArg = nil
end

function luaStoryboard:__construct(storyboardData, info)
	-- info parameter contains:
	-- ["path"] - beatmap path (optional)
	-- ["data"] - additional embedded data where value is FileData (optional)
	-- ["background"] - current background
	-- ["unit"] - unit image list, index from 1..9
	-- ["skill"] - skill callback function
	-- ["seed"] - random seed in {low, high}
	-- ["ui"] - current live ui as string

	self.beatmapData = {}
	self.beatmapPath = info.path
	if self.beatmapPath and self.beatmapPath:sub(-1) ~= "/" then
		self.beatmapPath = self.beatmapPath.."/"
	end

	-- Add FileDatas
	if info.data then
		for i = 1, #info.data do
			self.beatmapData[i] = info.data[i]
			self.beatmapData[info.data[i]:getFilename()] = info.data[i]
		end
	end

	-- variable setup
	self.sandbox = sandbox()
	self.pushPopCount = 0
	self.rng = love.math.newRandomGenerator(info.seed[1], info.seed[2])
	self.audio = info.song
	self.background = info.background
	self.units = info.unit
	self.canvas = love.graphics.newCanvas(1136, 728, canvas3rdArg)
	self.loadedAudioV2 = setmetatable({}, {__mode = "k"})
	self.liveUI = info.ui
	self.v3 = false

	-- Setup essential sandbox variables
	self:setupMainEnv()
	-- Setup sandbox environment
	self:setupV2Sandbox()

	local status, msg = loadstring(storyboardData, "luastoryboard")
	if status == nil then
		error(msg)
	end

	assert(self.sandbox:run(status))

	if self.v3 then
		-- TODO
	else
		local env = self.sandbox:getEnv()
		if env.Initialize then
			env.Initialize()
		end
	end
end

function luaStoryboard:setupMainEnv()
	-- It's worth noting that we can't use any asynchronous function
	-- or any caching mechanism in here. The reason we can't because
	-- Lua storyboard doesn't run inside coroutine, and if we give
	-- cached version of the requested data, the Lua storyboard may
	-- do something malicious by modifying the returned object
	-- (LOVE objects are mutable).
	-- So, to fix that, we call the respective LOVE function directly,
	-- bypassing any caching mechanism and cause the function
	-- to run synchronously. Not a best idea due to new asynchronous
	-- architecture, but for maximum sandboxing, this is actually the
	-- best way.
	self.mainEnv = {}

	-- LoadImage function
	function self.mainEnv.loadImage(path)
		if self.beatmapData[path] then
			return love.graphics.newImage(self.beatmapData[path], {mipmaps = true})
		elseif self.beatmapPath then
			return love.graphics.newImage(self.beatmapPath..path, {mipmaps = true})
		else
			error("image file not found")
		end
	end

	-- LoadFont function
	function self.mainEnv.loadFont(path, ...)
		if path == nil then
			local f = love.graphics.newFont(MainFont.roboto, ...)
			f:setFallbacks(love.graphics.newFont(MainFont.notoSansCJK, ...))
			return f
		elseif self.beatmapData[path] then
			return love.graphics.newFont(self.beatmapData[path], ...)
		elseif self.beatmapPath then
			return love.graphics.newFont(self.beatmapPath..path, ...)
		else
			error("font file not found")
		end
	end

	-- LoadVideo function
	function self.mainEnv.loadVideo(path)
		-- Note that video only supports loading from beatmap directory
		-- and can't load from FilData
		if self.beatmapPath then
			return loadVideoOnly(self.beatmapPath..path)
		else
			error("video file not found")
		end
	end

	-- ReadFile function
	function self.mainEnv.readFile(path)
		if self.beatmapData[path] then
			return self.beatmapData[path]:getString()
		elseif self.beatmapPath then
			return love.filesystem.read(self.beatmapPath..path)
		else
			error("file not found")
		end
	end
	-- GetCurrentAudioSample function
	function self.mainEnv.getCurrentAudioSample(size)
		local temp = {}

		if self.audio then
			local smp = self.audio:getSamples(size)
			-- smp is interleaved in form {l, r, l, r} but
			-- storyboard expects {{l, r}, {l, r}}
			for i = 1, #smp, 2 do
				temp[#temp + 1] = {smp[i], smp[i + 1]}
			end
		else
			for i = 1, size do
				temp[i] = {0, 0}
			end
		end

		return temp
	end
	-- GetCurrentAudioSampleRate function
	function self.mainEnv.getAudioSampleRate()
		return self.audio and self.audio:getSampleRate() or 48000
	end
	-- IsOpenGLES function
	function self.mainEnv.isGLES()
		-- Side note, LOVE developers say there may be
		-- Metal and Vulkan renderer in next version.
		-- In that case, `love.graphics.getRendererInfo()`
		-- won't return "OpenGL" nor "OpenGL ES".
		-- This function only check exactly for OpenGLES
		-- and nothing else.
		return love.graphics.getRendererInfo() == "OpenGL ES"
	end
	-- IsDesktopSystem function
	function self.mainEnv.isDesktop()
		return not(Util.isMobile())
	end
	-- IsRenderMode function
	function self.mainEnv.isRendering()
		return AudioManager.renderRate > 0
	end
end

local function pcallWrap(func)
	return function(...)
		local a, b = pcall(func, ...)
		if a then return b
		else return nil end
	end
end

function luaStoryboard:setupV2Sandbox()
	-- V2 storyboard uses PascalCase name
	-- plus `love` table exported.
	local env = self.sandbox:getEnv()
	env.DEPLS_VERSION = DEPLS_VERSION
	env.DEPLS_VERSION_NUMBER = DEPLS_VERSION_NUMBER

	-- V2 functions
	env.RequireDEPLSVersion = dummy -- always true
	env.LoadImage = pcallWrap(self.mainEnv.loadImage)
	env.LoadVideo = pcallWrap(self.mainEnv.loadVideo)
	env.LoadFont = pcallWrap(self.mainEnv.loadFont)
	env.LoadAudio = function(path)
		local s, audio

		if self.beatmapData[path] then
			s, audio = pcall(AudioManager.newAudioDirect, self.beatmapData[path], "voice")
		end

		if not(s) and self.beatmapPath then
			s, audio = pcall(AudioManager.newAudio, self.beatmapPath..path, "voice")
		end

		if s then
			-- Don't expose the actual object to user
			local opaque = {}
			self.loadedAudioV2[opaque] = audio
			return opaque
		end
	end
	env.ReadFile = pcallWrap(self.mainEnv.readFile)
	env.DrawObject = love.graphics.draw
	env.DrawRectangle = love.graphics.rectangle
	env.DrawCircle = love.graphics.circle
	env.DrawEllipse = love.graphics.ellipse
	env.DrawArc = love.graphics.arc
	env.PrintText = love.graphics.print
	env.SetColor = function(r, g, b, a)
		if type(r) == "table" then
			return love.graphics.setColor(color.compat(r[1], r[2], r[3], (r[4] or 255) / 255))
		else
			return love.graphics.setColor(color.compat(r, g, b, (a or 255) / 255))
		end
	end
	env.SetFont = love.graphics.setFont
	env.SetCanvas = function(canvas)
		love.graphics.setCanvas(canvas or self.canvas)
	end
	env.SetBlendMode = love.graphics.setBlendMode
	env.SetShader = love.graphics.setShader
	env.ClearDrawing = love.graphics.clear
	env.LoadShader = love.graphics.newShader
	env.NewCanvas = love.graphics.newCanvas

	-- DEPLS-specific functions
	env.SetLiveOpacity = dummy
	env.SetBackgroundDimOpacity = dummy
	env.GetCurrentElapsedTime = zeroret
	env.GetLiveSimulatorDelay = zeroret
	env.SpawnSpotEffect = dummy
	env.SpawnCircleTapEffect = dummy
	env.SetUnitOpacity = dummy
	env.LoadDEPLS2Image = function(path)
		local s, a = pcall(love.graphics.newImage, path)
		if s then return a end
		return nil
	end
	env.GetCurrentAudioSample = self.mainEnv.getCurrentAudioSample
	env.GetCurrentAudioSampleRate = self.mainEnv.getAudioSampleRate
	env.DisablePlaySpeedAlteration = dummy
	env.SetPlaySpeed = dummy
	env.ForceNoteStyle = dummy
	env.ForceNewNoteStyle = dummy
	env.IsRenderingMode = self.mainEnv.isRendering
	env.SkillPopup = dummy
	env.AllowComboCheer = dummy
	env.HSL = function(h, s, l)
		if s == 0 then return l,l,l end
		h, s, l = h/256*6, s/255, l/255
		local c = (1-math.abs(2*l-1))*s
		local x = (1-math.abs(h%2-1))*c
		local m = (l-.5*c)
		local r,g,b
		if h < 1     then r,g,b = c,x,0
		elseif h < 2 then r,g,b = x,c,0
		elseif h < 3 then r,g,b = 0,c,x
		elseif h < 4 then r,g,b = 0,x,c
		elseif h < 5 then r,g,b = x,0,c
		else              r,g,b = c,0,x
		end
		return math.ceil((r+m)*256),math.ceil((g+m)*256),math.ceil((b+m)*256)
	end
	env.IsOpenGLES = self.mainEnv.isGLES
	env.MultiVideoFormatSupported = falseret -- TODO
	env.GetCurrentBackgroundImage = function()
		return self.background
	end
	env.GetCurrentUnitImage = function(index)
		return assert(self.units[index], "invalid unit position")
	end
	env.AddScore = dummy
	env.SetRedTimingDuration = dummy
	env.SetYellowTimingDuration = dummy
	-- Live Simulator: 2 v3.0 stops calling storyboard function on complete
	env.IsLiveEnded = falseret
	env.IsRandomMode = falseret
	env.GetScreenDimensions = function()
		return 960, 640
	end
	env.GetLiveUI = function()
		return self.liveUI
	end
	env.IsDesktopSystem = self.mainEnv.isDesktop
	env.UseZeroToOneColorRange = function()
		env.SetColor = function(r, g, b, a)
			if type(r) == "table" then
				return love.graphics.setColor(color.compat(r[1] * 255, r[2] * 255, r[3] * 255, r[4] or 1))
			else
				return love.graphics.setColor(color.compat(r * 255, g * 255, b * 255, a or 1))
			end
		end
	end
	env.SetPostProcessingShader = dummy -- TODO

	-- RNG patching
	env.math.random = function(...)
		return self.rng:random(...)
	end
	env.math.randomseed = nil

	-- Isolated love
	env.love = {
		graphics = {
			arc = love.graphics.arc,
			circle = love.graphics.circle,
			clear = love.graphics.clear,
			draw = love.graphics.draw,
			ellipse = love.graphics.ellipse,
			line = love.graphics.line,
			origin = function()
				love.graphics.origin()
				love.graphics.translate(88, 43)
			end,
			points = love.graphics.points,
			polygon = love.graphics.polygon,
			print = love.graphics.print,
			printf = love.graphics.printf,
			rectangle = love.graphics.rectangle,

			newCanvas = love.graphics.newCanvas,
			newFont = env.LoadFont,
			newImage = env.LoadImage,
			newMesh = love.graphics.newMesh,
			newParticleSystem = love.graphics.newParticleSystem,
			newShader = love.graphics.newShader,
			newSpriteBatch = love.graphics.newSpriteBatch,
			newQuad = love.graphics.newQuad,
			newVideo = env.LoadVideo,

			setBlendMode = love.graphics.setBlendMode,
			setCanvas = env.SetCanvas,
			setColor = env.SetColor,
			setColorMask = love.graphics.setColorMask,
			setLineStyle = love.graphics.setLineStyle,
			setLineWidth = love.graphics.setLineWidth,
			setScissor = love.graphics.setScissor,
			setShader = love.graphics.setShader,
			setFont = love.graphics.setFont,

			pop = function()
				if self.pushPopCount > 0 then
					love.graphics.pop()
					self.pushPopCount = self.pushPopCount - 1
				end
			end,
			push = function()
				love.graphics.push()
				self.pushPopCount = self.pushPopCount + 1
			end,
			rotate = love.graphics.rotate,
			scale = love.graphics.scale,
			shear = love.graphics.shear,
			translate = love.graphics.translate
		},
		math = {
			compress = function(rawstring, format, level)
				if love._version >= "11.0" then
					return love.data.compress("data", format, rawstring, level)
				else
					return love.math.compress(rawstring, format, level)
				end
			end,
			decompress = function(compressedString, format)
				if love._version >= "11.0" then
					if type(compressedString) == "userdata" and compressedString:typeOf("CompressedData") then
						return love.data.decompress("string", compressedString)
					else
						return love.data.decompress("string", format, compressedString)
					end
				else
					return love.math.decompress(compressedString, format)
				end
			end,
			newBezierCurve = love.math.newBezierCurve,
			newRandomGenerator = love.math.newRandomGenerator,
			noise = love.math.noise,
			random = env.math.random
		},
		timer = {
			getAverageDelta = love.timer.getAverageDelta,
			getDelta = love.timer.getDelta,
			getTime = love.timer.getTime,
		}
	}

	-- Compatibility upgrade
	env.newStoryboard = function(version)
		if self.v3 then return end

		version = version or 0
		assert(version == 0, "invalid storyboard version")

		-- setupV3Sandbox is also responsible removing V2 variables
		self:setupV3Sandbox()
		self.v3 = true
	end

	-- modules preload
	self.sandbox:preloadModule("tween", love.filesystem.load("libs/tween.lua"))
	self.sandbox:preloadModule("complex", love.filesystem.load("libs/complex.lua"))
	self.sandbox:preloadModule("luafft", love.filesystem.load("libs/luafft.lua"))
end

function luaStoryboard:setupV3Sandbox()
	-- Clear v2 vars
	local env = self.sandbox:getEnv()
	env.love = nil
	env.RequireDEPLSVersion = nil
	env.LoadImage = nil
	env.LoadVideo = nil
	env.LoadFont = nil
	env.LoadAudio = nil
	env.ReadFile = nil
	env.DrawObject = nil
	env.DrawRectangle = nil
	env.DrawCircle = nil
	env.DrawEllipse = nil
	env.DrawArc = nil
	env.PrintText = nil
	env.SetColor = nil
	env.SetFont = nil
	env.SetCanvas = nil
	env.SetBlendMode = nil
	env.SetShader = nil
	env.ClearDrawing = nil
	env.LoadShader = nil
	env.NewCanvas = nil
	env.SetLiveOpacity = nil
	env.SetBackgroundDimOpacity = nil
	env.GetCurrentElapsedTime = nil
	env.GetLiveSimulatorDelay = nil
	env.SpawnSpotEffect = nil
	env.SpawnCircleTapEffect = nil
	env.SetUnitOpacity = nil
	env.LoadDEPLS2Image = nil
	env.GetCurrentAudioSample = nil
	env.GetCurrentAudioSampleRate = nil
	env.DisablePlaySpeedAlteration = nil
	env.SetPlaySpeed = nil
	env.ForceNoteStyle = nil
	env.ForceNewNoteStyle = nil
	env.IsRenderingMode = nil
	env.SkillPopup = nil
	env.AllowComboCheer = nil
	env.IsOpenGLES = nil
	env.MultiVideoFormatSupported = nil
	env.GetCurrentBackgroundImage = nil
	env.GetCurrentUnitImage = nil
	env.AddScore = nil
	env.SetRedTimingDuration = nil
	env.SetYellowTimingDuration = nil
	env.IsLiveEnded = nil
	env.IsRandomMode = nil
	env.GetScreenDimensions = nil
	env.GetLiveUI = nil
	env.IsDesktopSystem = nil
	env.UseZeroToOneColorRange = nil
	env.SetPostProcessingShader = nil

	-- Put v3 vars
	env.__background = self.background
	for i = 1, 9 do
		env["__unit_"..i] = self.units[i]
	end
	env.registerCallback = dummy -- TODO
	env.setLiveOpacity = dummy -- TODO
	env.loadImage = self.mainEnv.loadImage
	env.loadVideo = self.mainEnv.loadVideo
	env.loadFont = self.mainEnv.loadFont
	env.readFile = self.mainEnv.readFile
	env.setUnitOpacity = dummy -- TODO
	env.getCurrentAudioSample = self.mainEnv.getCurrentAudioSample
	env.getAudioSampleRate = self.mainEnv.getAudioSampleRate
	env.addScore = dummy -- TODO
	env.setRedTimingDuration = dummy -- TODO
	env.setYellowTimingDuration = dummy -- TODO
	env.isRandom = falseret -- TODO
	env.setPostProcessingShader = dummy -- TODO
	env.graphics = {
		-- TODO
	}
end

local xpcallWrapData = {
	dt = 0,
	dest = nil
}
xpcallWrapData.func = function()
	return xpcallWrapData.dest(xpcallWrapData.dt)
end

function luaStoryboard:update(dt)
	if self.v3 then
		-- TODO
	else
		local env = self.sandbox:getEnv()
		love.graphics.push("all")
		love.graphics.origin()
		love.graphics.setCanvas(self.canvas)
		love.graphics.translate(88, 43)
		xpcallWrapData.dest = env.Update
		xpcallWrapData.dt = dt * 1000
		local status, msg = xpcall(xpcallWrapData.func, debug.traceback)
		-- Rebalance push/pop
		for _ = 1, self.pushPopCount do
			love.graphics.pop()
		end
		self.pushPopCount = 0
		love.graphics.pop()

		if not(status) then
			log.errorf("luastoryboard", msg)
		end
	end
end

function luaStoryboard:draw()
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setColor(color.white)
	love.graphics.draw(self.canvas, -88, -43)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function luaStoryboard.callback()
	-- TODO
end

return luaStoryboard
