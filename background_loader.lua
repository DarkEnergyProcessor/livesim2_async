-- Background Loading management
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- The background image must be placed in specific order:
-- Main background in +0+43
-- Up patch in +0+0
-- Bottom patch in +0+683
-- Left patch in +640+750 rotated by 90degree
-- Right patch in +640+864 rotated by 90degree

--[[
-- Lua script to create the ImageMagick command to do those:
local id = assert(tonumber(arg[1]))
local mainBg = string.format("liveback_%d.png", id)
local leftBg = string.format("b_liveback_%03d_01.png", id)
local rightBg = string.format("b_liveback_%03d_02.png", id)
local topBg = string.format("b_liveback_%03d_03.png", id)
local bottomBg = string.format("b_liveback_%03d_04.png", id)

local cmd = setmetatable({}, {__call = function(cmd, ...)
	for i = 1, select("#", ...) do
		cmd[#cmd + 1] = select(i, ...)
	end
end})
cmd(
	"magick convert -size 1024x1024 xc:none",
	mainBg, "-geometry +0+43 -composite",
	topBg, "-geometry +0+0 -composite",
	bottomBg, "-geometry +0+683 -composite",
	"(", leftBg, "-rotate 90 ) -geometry +0+750 -composite",
	"(", rightBg, "-rotate 90 ) -geometry +0+864 -composite",
	id..".png"
)
os.exit(os.execute(table.concat(cmd, " ")))
]]

local AquaShine = ...
local love = require("love")
local BackgroundLoader = {}
BackgroundLoader.Cache = setmetatable({}, {mode = "v"})

local function quadToTriangle(pos)
	local triangle = {}
	triangle[#triangle + 1] = {pos[1][1], pos[1][2], (pos[1][3]+.5)/1024, (pos[1][4]+.5)/1024}
	triangle[#triangle + 1] = {pos[2][1], pos[2][2], (pos[2][3]+.5)/1024, (pos[2][4]+.5)/1024}
	triangle[#triangle + 1] = {pos[3][1], pos[3][2], (pos[3][3]+.5)/1024, (pos[3][4]+.5)/1024}
	triangle[#triangle + 1] = {pos[3][1], pos[3][2], (pos[3][3]+.5)/1024, (pos[3][4]+.5)/1024}
	triangle[#triangle + 1] = {pos[4][1], pos[4][2], (pos[4][3]+.5)/1024, (pos[4][4]+.5)/1024}
	triangle[#triangle + 1] = {pos[1][1], pos[1][2], (pos[1][3]+.5)/1024, (pos[1][4]+.5)/1024}
	return triangle
end

local function mergeTable(...)
	local res = {}
	for i = 1, select("#", ...) do
		local t = select(i, ...)
		for j = 1, #t do
			res[#res + 1] = t[j]
		end
	end
	return res
end

BackgroundLoader.MeshData = mergeTable(
	-- Main background
	quadToTriangle {
		{0, 0, 0, 43},
		{0, 640, 0, 682},
		{960, 640, 959, 682},
		{960, 0, 959, 43}
	},
	-- Left patch
	quadToTriangle {
		{-88, 0, 639, 750},
		{-88, 640, 0, 750},
		{0, 640, 0, 837},
		{0, 0, 639, 837}
	},
	-- Right patch
	quadToTriangle {
		{960, 0, 639, 864},
		{960, 640, 0, 864},
		{1048, 640, 0, 951},
		{1048, 0, 639, 951}
	},
	-- Top patch
	quadToTriangle {
		{0, -43, 0, 0},
		{0, 0, 0, 42},
		{960, 0, 959, 42},
		{960, -43, 959, 0}
	},
	-- Bottom patch
	quadToTriangle {
		{0, 640, 0, 683},
		{0, 683, 0, 725},
		{960, 683, 959, 725},
		{960, 640, 959, 683},
	}
)

function BackgroundLoader.LoadDirect(id)
	local img = assert(AquaShine.LoadImage(string.format("assets/image/background/%d.png", id)) or nil)
	local mesh = love.graphics.newMesh(BackgroundLoader.MeshData, "triangles", "static")
	mesh:setTexture(img)
	return mesh
end

function BackgroundLoader.Load(id)
	if not(BackgroundLoader.Cache[id]) then
		BackgroundLoader.Cache[id] = BackgroundLoader.LoadDirect(id)
	end
	return BackgroundLoader.Cache[id]
end

function BackgroundLoader.Compose(main, left, right, top, bottom)
	local framebuffer = love.graphics.newCanvas(1024, 1024)

	love.graphics.push("all")
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setCanvas(framebuffer)
	love.graphics.clear()
	love.graphics.origin()

	-- Draw background
	love.graphics.draw(main, 0, 43, 0, 960 / main:getWidth(), 640 / main:getHeight())
	if left   then love.graphics.draw(left  , 639, 750, math.pi/2) end
	if right  then love.graphics.draw(right , 639, 864, math.pi/2) end
	if top    then love.graphics.draw(top   , 0  , 0  , 0        ) end
	if bottom then love.graphics.draw(bottom, 0  , 683, 0        ) end
	love.graphics.pop()

	local mesh = love.graphics.newMesh(BackgroundLoader.MeshData, "triangles", "static")
	mesh:setTexture(framebuffer)
	return mesh
end

return BackgroundLoader
