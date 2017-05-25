-- Lua storyboard handler
-- Copyright © 2038 Dark Energy Processor
local Shelsha = require("Shelsha")

local DEPLS = DEPLS		-- TODO: Should be avoided if possible
local AquaShine = AquaShine

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
		return love.filesystem.read(BeatmapDir..path), nil
	end
	
	return nil
end

local VideoList = {}
local function RelativeLoadVideo(path)
	if BeatmapDir then
		local _, x = pcall(love.graphics.newVideo, BeatmapDir..path, false)
		
		if _ then
			VideoList[#VideoList + 1] = x
			
			return x
		end
	end
	
	return nil
end

local function RelativeLoadImage(path)
	if AdditionalData[path] then
		return love.graphics.newImage(AdditionalData[path])
	end
	
	if BeatmapDir then
		local _, x = pcall(love.graphics.newImage, BeatmapDir..path)
		if _ then return x end
	end
	
	return nil
end

local function LoadTextureBank(file)
	if AdditionalData[file] then
		local _, a = pcall(Shelsha.newTextureBank, AdditionalData[file])
		
		if _ then return a end
	end
	
	if BeatmapDir then
		local x = love.filesystem.newFileData(BeatmapDir..file)
		
		if not(x) then return nil end
		
		local _, a = pcall(Shelsha.newTextureBank, x)
		
		if _ then return a end
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
			assert(love.graphics.getCanvas() ~= AquaShine.MainCanvas, "love.graphics.clear on real screen is not allowed!")
			love.graphics.clear(...)
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
		newFont = AquaShine.LoadFont,
		newImage = RelativeLoadImage,
		newMesh = love.graphics.newMesh,
		newParticleSystem = love.graphics.newParticleSystem,
		newShader = love.graphics.newShader,
		newSpriteBatch = love.graphics.newSpriteBatch,
		newQuad = love.graphics.newQuad,
		newVideo = RelativeLoadVideo,
		
		setBlendMode = love.graphics.setBlendMode,
		setCanvas = function(canvas)
			love.graphics.setCanvas(canvas or AquaShine.MainCanvas)
		end,
		setColor = love.graphics.setColor,
		setColorMask = love.graphics.setColorMask,
		setLineStyle = love.graphics.setLineStyle,
		setLineWidth = love.graphics.setLineWidth,
		setScissor = love.graphics.setScissor,
		setShader = love.graphics.setShader,
		setFont = love.graphics.setFont,
		
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
		ReadFile = RelativeReadFile,
		DrawObject = love.graphics.draw,
		LoadTextureBank = LoadTextureBank,
		LoadShader = love.graphics.newShader,
		LoadFont = AquaShine.LoadFont,
		
		-- Deprecated. Exists for backward compatibility. Removed anytime soon
		FontManager = {GetFont = AquaShine.LoadFont}
	}
	
	for n, v in pairs(_G) do
		env[n] = v
	end
	
	for n, v in pairs(DEPLS.StoryboardFunctions) do
		env[n] = v
	end
	
	-- Remove some dayas
	env._G = env
	env.io = nil
	env.os = nil
	env.debug = nil
	env.loadfile = nil
	env.dofile = nil
	env.package = nil
	env.love = isolated_love
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
		return (assert(allowed_libs[libname], "require is limited in storyboard lua script"))
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
	
	graphics.push("all")
	
	local status, msg
	if StoryboardLua[3] then
		status, msg = pcall(StoryboardLua[2].Update, deltaT)
	else
		status, msg = pcall(StoryboardLua[1], deltaT)
	end
	
	-- Rebalance push/pop
	for i = 1, PushPopCount do
		graphics.pop()
	end
	PushPopCount = 0
	
	-- Cleanup
	graphics.pop()
	
	if status == false then
		print("Storyboard Error: "..msg)
	end
end

function LuaStoryboard.SetAdditionalFiles(datas)
	AdditionalData = assert(type(datas) == "table" and datas, "bad argument #1 to 'SetAdditionalFiles' (table expected)")
end

function LuaStoryboard.Cleanup()
	for i = 1, #VideoList do
		VideoList[i]:pause()
		VideoList[i] = nil
	end
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
