-- Lua storyboard handler
local LuaStoryboard = {}
local BeatmapDir
local StoryboardLua

local function RelativeLoadVideo(path, loadaudio)
	local x = love.filesystem.newFile(BeatmapDir..path)
	
	if not(x) then return nil end
	
	return love.graphics.newVideo(love.video.newVideoStream(x), loadaudio)
end

-- Storyboard lua file
function LuaStoryboard.Load(file)
	local lua = love.filesystem.load(file)
	BeatmapDir = file:sub(1, file:find("[^/]+$") - 1)
	
	-- Copy environment
	local env = {
		RelativeLoadVideo = RelativeLoadVideo
	}
	for n, v in pairs(_G) do
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
