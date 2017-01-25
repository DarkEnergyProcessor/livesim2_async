-- Lua storyboard handler
-- Copyright © 2038 Dark Energy Processor

-- The DEPLS handle
local DEPLS = _G.DEPLS

-- The Lua storyboard
local LuaStoryboard = {}
local AdditionalData = {}
local BeatmapDir
local StoryboardLua

-- Used to isolate love.graphics.push and love.graphics.pop
local PushPopCount = 0

local function RelativeReadFile(path)
	if AdditionalData[path] then
		return AdditionalData[path]:getString()
	end
	
	if BeatmapDir then
		local x = love.filesystem.newFileData(BeatmapDir..path)
		
		if not(x) then return nil end
		
		return x:getString()
	end
	
	return nil
end

local function RelativeLoadVideo(path, loadaudio)
	if AdditionalData[path] then
		return love.graphics.newVideo(AdditionalData[path], loadaudio)
	end
	
	if BeatmapDir then
		local x = love.filesystem.newFile(BeatmapDir..path, "r")
		
		if not(x) then return nil end
		
		return love.graphics.newVideo(love.video.newVideoStream(x), loadaudio)
	end
	
	return nil
end

local function RelativeLoadImage(path)
	if AdditionalData[path] then
		return love.graphics.newImage(AdditionalData[path])
	end
	
	if BeatmapDir then
		local x = love.filesystem.newFileData(BeatmapDir..path)
		
		if not(x) then return nil end
		
		return love.graphics.newImage(x)
	end
	
	return nil
end

-- Used to isolate function and returns table of all created global variable
local function isolate_globals(func)
	local env = {}
	local created_vars = {}
	
	for n, v in pairs(_G) do
		env[n] = v
	end
	
	setmetatable(env, {
		__newindex = function(a, b, c)
			created_vars[b] = c
			rawset(a, b, c)
		end
	})
	setfenv(func, env)
	func()
	
	return created_vars
end

local isolated_love = {
	graphics = {
		arc = love.graphics.arc,
		circle = love.graphics.circle,
		clear = function(...)
			if love.graphics.getCanvas() then
				love.graphics.clear(...)
			else
				error("love.graphics.clear on real screen is forbidden!")
			end
		end,
		draw = love.graphics.draw,
		ellipse = love.graphics.ellipse,
		line = love.graphics.line,
		points = love.graphics.points,
		polygon = love.graphics.polygon,
		print = love.graphics.print,
		printf = love.graphics.printf,
		rectangle = love.graphics.rectangle,
		
		newCanvas = love.graphics.newCanvas,
		newImage = RelativeLoadImage,
		newMesh = love.graphics.newMesh,
		newParticleSystem = love.graphics.newParticleSystem,
		newShader = love.graphics.newShader,
		newSpriteBatch = love.graphics.newSpriteBatch,
		newQuad = love.graphics.newQuad,
		newVideo = RelativeLoadVideo,
		
		setBlendMode = love.graphics.setBlendMode,
		setCanvas = love.graphics.setCanvas,
		setColor = love.graphics.setColor,
		setColorMask = love.graphics.setColorMask,
		setLineStyle = love.graphics.setLineStyle,
		setLineWidth = love.graphics.setLineWidth,
		setScissor = love.graphics.setScissor,
		setShader = love.graphics.setShader,
		
		pop = function()
			if PushPopCount > 0 then
				love.graphics.pop()
				PushPopCount = PushPopCount - 1 
			end
		end,
		push = function()
			love.graphics.push()
			PushPopCount = PushPopCount + 1
		end,
		rotate = love.graphics.rotate,
		scale = love.graphics.scale,
		shear = love.graphics.shear,
		translate = love.graphics.translate
	},
	math = love.math,
	timer = love.timer
}

-- List of whitelisted libraries for storyboard
local allowed_libs = {
	JSON = require("JSON"),
	List = require("List"),
	tween = require("tween"),
	EffectPlayer = require("effect_player"),
	luafft = isolate_globals(love.filesystem.load("luafft.lua")),
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

-- Storyboard lua file
function LuaStoryboard.LoadString(str, dir)
	local lua = type(str) == "function" and str or loadstring(str)
	BeatmapDir = dir
	
	-- Copy environment
	local env = {
		LoadVideo = RelativeLoadVideo,
		LoadImage = RelativeLoadImage,
		ReadFile = RelativeReadFile
	}
	
	for n, v in pairs(_G) do
		env[n] = v
	end
	
	for n, v in pairs(DEPLS.StoryboardFunctions) do
		env[n] = v
	end
	
	-- Disable some libraries
	env.DEPLS = nil
	env.io = nil
	env.os = nil
	env.debug = nil
	env.loadfile = nil
	env.dofile = nil
	env.package = nil
	env.love = isolated_love
	env.file_get_contents = nil
	env.LogicalScale = nil
	env.CalculateTouchPosition = nil
	env.LoadConfig = nil
	env.LoadEntryPoint = nil
	env.require = function(libname)
		if allowed_libs[libname] then
			return allowed_libs[libname]
		end
		
		error("require is limited in storyboard lua script")
	end
	
	setfenv(lua, env)
	
	-- Call state once
	local luastate = coroutine.wrap(lua)
	luastate()
	
	if env.Initialize then
		env.Initialize()
	end
	
	StoryboardLua = {
		coroutine.wrap(lua),				-- The lua storyboard
		env,								-- The global variables
		env.Update or env.Initialize,		-- New DEPLS2 storyboard or usual DEPLS storyboard
	}
end

function LuaStoryboard.Load(file)
	LuaStoryboard.LoadString(love.filesystem.load(file), file:sub(1, file:find("[^/]+$") - 1))
end

local graphics = love.graphics

function LuaStoryboard.Draw(deltaT)
	if not(StoryboardLua) then return end
	
	graphics.push()
	
	local status, msg
	if StoryboardLua[3] then
		--status, msg = pcall(StoryboardLua[2].Update, deltaT)
		StoryboardLua[2].Update(deltaT)
	else
		status, msg = pcall(StoryboardLua[1], deltaT)
	end
	
	for i = 1, PushPopCount do
		graphics.pop()
	end
	PushPopCount = 0
	
	-- Cleanup
	graphics.pop()
	graphics.setCanvas()
	graphics.setScissor()
	graphics.setColor(255, 255, 255, 255)
	graphics.setColorMask()
	graphics.setBlendMode("alpha")
	graphics.setShader()
	
	if status == false then
		print("Storyboard Error: "..msg)
	end
end

function LuaStoryboard.SetAdditionalFiles(datas)
	AdditionalData = assert(type(datas) == "table" and datas, "bad argument #1 to 'SetAdditionalFiles' (table expected)")
end

-- Callback functions
function LuaStoryboard.On(name, ...)
	local callback_name = "On"..name
	
	if StoryboardLua[3] and StoryboardLua[2][callback_name] then
		local a, b = {pcall(StoryboardLua[2][callback_name], ...)}
		
		if a == false then
			print("Storyboard Error "..callback_name..": "..b)
		end
	end
end

return LuaStoryboard
