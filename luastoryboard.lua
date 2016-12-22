-- Lua storyboard handler
local DEPLS = _G.DEPLS
local LuaStoryboard = {}
local BeatmapDir
local StoryboardLua

local function RelativeLoadVideo(path, loadaudio)
	local x = love.filesystem.newFile(BeatmapDir..path, "r")
	
	if not(x) then return nil end
	
	return love.graphics.newVideo(love.video.newVideoStream(x), loadaudio)
end

local function RelativeLoadImage(path)
	local x = love.filesystem.newFileData(BeatmapDir..path)
	
	if not(x) then return nil end
	
	return love.graphics.newImage(x)
end

-- Storyboard lua file
function LuaStoryboard.Load(file)
	local lua = love.filesystem.load(file)
	BeatmapDir = file:sub(1, file:find("[^/]+$") - 1)
	
	-- Copy environment
	local env = {
		DEPLS = DEPLS,
		RelativeLoadVideo = RelativeLoadVideo,
		RelativeLoadImage = RelativeLoadImage,
		LoadVideo = RelativeLoadVideo,
		LoadImage = RelativeLoadImage,
		GetCurrentElapsedTime = function() return DEPLS.ElapsedTime end
	}
	for n, v in pairs(_G) do
		env[n] = v
	end
	for n, v in pairs(DEPLS.StoryboardFunctions) do
		env[n] = v
	end
	
	setfenv(lua, env)
	StoryboardLua = coroutine.wrap(lua)
end

function LuaStoryboard.Draw(deltaT)
	if not(StoryboardLua) then return end
	
	StoryboardLua(deltaT)
end

return LuaStoryboard
