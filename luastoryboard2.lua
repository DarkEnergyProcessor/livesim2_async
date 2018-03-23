-- Lua storyboard handler
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- As of v2.0, AquaShine no longer in global namespace and must be set separately
local AquaShine
local love = require("love")
local StoryboardBase = require("storyboard_base")
local LuaStoryboard = {}

-- List of whitelisted libraries for storyboard
local allowed_libs = {
	JSON = require("JSON"),
	tween = require("tween"),
	EffectPlayer = require("effect_player"),
	luafft = require("luafft"),
	string = string,
	table = table,
	math = math,
	coroutine = coroutine,
	bit = require("bit"),
	os = {
		time = os.time,
		clock = os.clock
	}
}

local function setup_env(story, lua)
	AquaShine.Log("LuaStoryboard", "Initializing environment")

	-- Copy environment
	local env = {
		RequireDEPLSVersion = function(ver)
			if ver < _G.DEPLS_VERSION then
				error("Incompatible storyboard!", 2)
			end
		end,
		LoadVideo = function(path)
			if story.BeatmapDir then
				local s, x = pcall(AquaShine.LoadVideo, story.BeatmapDir..path)

				if s then
					story.VideoList[#story.VideoList + 1] = x

					return x
				end
			end

			return nil
		end,
		LoadImage = function(path)
			if story.AdditionalData[path] then
				return love.graphics.newImage(story.AdditionalData[path])
			end

			if story.BeatmapDir then
				local _, x = pcall(love.graphics.newImage, story.BeatmapDir..path)
				if _ then return x end
			end

			return nil
		end,
		ReadFile = function(path)
			if story.AdditionalData[path] then
				return story.AdditionalData[path]:getString()
			end

			if story.BeatmapDir then
				return love.filesystem.read(story.BeatmapDir..path), nil
			end

			return nil
		end,
		DrawObject = love.graphics.draw,
		DrawRectangle = love.graphics.rectangle,
		DrawCircle = love.graphics.circle,
		DrawArc = love.graphics.arc,
		PrintText = love.graphics.print,
		SetColor = function(r, g, b, a)
			if type(r) == "table" then
				return love.graphics.setColor(r[1] / 255, r[2] / 255, r[3] / 255, (r[4] or 255) / 255)
			else
				return love.graphics.setColor(r / 255, g / 255, b / 255, (a or 255) / 255)
			end
		end,
		SetFont = love.graphics.setFont,
		LoadShader = love.graphics.newShader,
		LoadFont = function(path, size)
			if not(path) then
				return love.graphics.newFont("MTLmr3m.ttf", size or 14)
			end

			if story.AdditionalData[path] then
				return love.graphics.newFont(story.AdditionalData[path], size or 14)
			end

			if story.BeatmapDir then
				local s, x = pcall(love.graphics.newFont, story.BeatmapDir..path, size or 14)

				if s then
					return x
				end

			end

			return nil
		end
	}

	for n, v in pairs(_G) do
		env[n] = v
	end

	if story.AdditionalFunctions then
		for n, v in pairs(story.AdditionalFunctions) do
			env[n] = v
		end
	end

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
			setCanvas = function(canvas)
				love.graphics.setCanvas(canvas or story.Canvas)
			end,
			setColor = env.SetColor,
			setColorMask = love.graphics.setColorMask,
			setLineStyle = love.graphics.setLineStyle,
			setLineWidth = love.graphics.setLineWidth,
			setScissor = love.graphics.setScissor,
			setShader = love.graphics.setShader,
			setFont = love.graphics.setFont,

			pop = function()
				if story.PushPopCount > 0 then
					love.graphics.pop()
					story.PushPopCount = story.PushPopCount - 1
				end
			end,
			push = function()
				love.graphics.push()
				story.PushPopCount = story.PushPopCount + 1
			end,
			rotate = love.graphics.rotate,
			scale = love.graphics.scale,
			shear = love.graphics.shear,
			translate = love.graphics.translate
		},
		math = love.math,
		timer = love.timer
	}

	-- Remove some datas
	env._G = env
	env.DEPLS_DIST = nil
	env.io = nil
	env.os = nil
	env.debug = nil
	env.loadfile = nil
	env.dofile = nil
	env.package = nil
	env.file_get_contents = nil
	env.arg = nil
	env.AquaShine = nil
	env.NoteImageCache = nil
	env.dt = nil
	env.gcinfo = nil
	env.module = nil
	env.jit = nil
	env.collectgarbage = nil
	env.getfenv = nil
	env.require = function(libname)
		if allowed_libs[libname] then
			return allowed_libs[libname]
		elseif story.CacheRequire[libname] then
			return story.CacheRequire[libname]
		else
			local luaname = libname:gsub("%.", "/")..".lua"

			if story.AdditionalData[luaname] then
				local chunk = loadstring(story.AdditionalData[luaname], "@"..luaname)
				setfenv(chunk, env)
				story.CacheRequire[libname] = chunk(libname) or true
			else
				error("require is limited in storyboard lua script", 2)
			end
		end
	end
	env.print = function(...)
		local a = {}

		for n, v in ipairs({...}) do
			a[#a + 1] = tostring(v)
		end

		AquaShine.Log("storyboard", table.concat(a, "\t"))
	end
	env.UseZeroToOneColorRange = function()
		story.AdditionalFunctions._SetColorRange(1)
		env.love.graphics.setColor = love.graphics.setColor
		env.SetColor = love.graphics.setColor
	end
	env._SetColorRange = nil	-- Internal function @ livesim.lua

	setfenv(lua, env)

	-- Call state once
	lua()
	AquaShine.Log("LuaStoryboard", "Lua script storyboard initialized")

	if env.Initialize then
		env.Initialize()
	end

	story.StoryboardLua = env
end

local function storyboard_draw(this, deltaT)
	if not(this.Paused) then
		love.graphics.push("all")
		love.graphics.origin()
		love.graphics.translate(88, 43)
		love.graphics.setCanvas(this.Canvas)
		love.graphics.clear()

		local status, msg = xpcall(this.StoryboardLua.Update, debug.traceback, deltaT)

		-- Rebalance push/pop
		for _ = 1, this.PushPopCount do
			love.graphics.pop()
		end
		this.PushPopCount = 0

		-- Cleanup
		love.graphics.pop()

		if status == false then
			AquaShine.Log("LuaStoryboard", "Storyboard Error: %s", msg)
		end
	end

	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(this.Canvas, -88, -43)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

local function storyboard_setfiles(this, datas)
	this.AdditionalData = assert(type(datas) == "table" and datas, "bad argument #1 to 'SetAdditionalFiles' (table expected)")
end

local function storyboard_cleanup(this)
	for i = 1, #this.VideoList do
		this.VideoList[i]:pause()
	end

	this.VideoList = nil
	this.StoryboardLua = nil
	love.handlers.lowmemory()
end

local function storyboard_pause(this)
	if not(this.Paused) then
		for i = 1, #this.VideoList do
			local vid = this.VideoList[i]
			this.PausedVideos[vid] = vid:isPlaying()
			vid:pause()
		end

		this.Paused = true
	end
end

local function storyboard_resume(this)
	if this.Paused then
		for i = 1, #this.VideoList do
			local vid = this.VideoList[i]

			if this.PausedVideos[vid] then
				vid:play()
			end
			
			this.PausedVideos[vid] = nil
		end
		
		this.Paused = false
	end
end

local function storyboard_callback(this, name, ...)
	local callback_name = "On"..name
	
	if this.StoryboardLua[callback_name] then
		local a, b = xpcall(this.StoryboardLua[callback_name], debug.traceback, ...)
		
		if a == false then
			AquaShine.Log("LuaStoryboard", "Storyboard Error %s: %s", callback_name, b)
		end
	end
end

local function storyboard_initialize(this, export)
	this.AdditionalFunctions = export
	
	return setup_env(this, this.Lua)
end

function LuaStoryboard.LoadString(str, dir, export)
	local story = StoryboardBase.CreateDummy()
	local lua = type(str) == "function" and str or loadstring(str)
	
	-- Set functions
	story.Initialize = storyboard_initialize
	story.Draw = storyboard_draw
	story.SetAdditionalFiles = storyboard_setfiles
	story.Cleanup = storyboard_cleanup
	story.Callback = storyboard_callback
	story.Pause = storyboard_pause
	story.Resume = storyboard_resume
	
	story.Lua = lua
	story.BeatmapDir = dir
	story.AdditionalData = {}
	story.AdditionalFunctions = export
	story.VideoList = {}
	story.PushPopCount = 0
	story.Canvas = love.graphics.newCanvas(1136, 726)
	story.Paused = false
	story.PausedVideos = {}
	story.CacheRequire = {}
	
	return story
end

function LuaStoryboard.Load(file, export)
	return LuaStoryboard.LoadString(
		love.filesystem.load(file),
		file:sub(1, file:find("[^/]+$") - 1),
		export
	)
end

-- As of v2.0, AquaShine no longer in global namespace and must be set in main.lua
function LuaStoryboard._SetAquaShine(aqs)
	AquaShine = aqs
end

return LuaStoryboard
