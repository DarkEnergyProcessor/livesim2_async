-- Virtual Resolution System
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local vires = {
	data = {
		virtualW = 0,
		virtualH = 0,
		offX = 0,
		offY = 0,
		scaleOverall = 1
	},
	isInit = false
}

function vires.init(width, height)
	if vires.isInit then return end
	vires.data.virtualW, vires.data.virtualH = width, height
	vires.isInit = true

	-- Create background sprite batch.
	-- Cannot use async here because it's not available.
	local thickness = 3
	vires.spriteBatch = love.graphics.newSpriteBatch(
		love.graphics.newImage("assets/image/background/pattern.png"),
		thickness * 26
	)
	local patternMyus = love.graphics.newQuad(0, 0, 128, 128, 256, 128)
	local patternAqua = love.graphics.newQuad(128, 0, 128, 128, 256, 128)

	for i = 0, thickness-1 do
		-- Myus, left, Y start at 0
		vires.spriteBatch:add(patternMyus, -i * 128, 0, 0, 1, 1, 128, 0)
		vires.spriteBatch:add(patternMyus, -i * 128, 128, 0, 1, 1, 128, 0)
		vires.spriteBatch:add(patternMyus, -i * 128, 256, 0, 1, 1, 128, 0)
		vires.spriteBatch:add(patternMyus, -i * 128, 384, 0, 1, 1, 128, 0)
		vires.spriteBatch:add(patternMyus, -i * 128, 512, 0, 1, 1, 128, 0)
		-- Aqua, right, Y start at 0
		vires.spriteBatch:add(patternAqua, 960 + i * 128, 0)
		vires.spriteBatch:add(patternAqua, 960 + i * 128, 128)
		vires.spriteBatch:add(patternAqua, 960 + i * 128, 256)
		vires.spriteBatch:add(patternAqua, 960 + i * 128, 384)
		vires.spriteBatch:add(patternAqua, 960 + i * 128, 512)
		-- Myus, top, X start at -64
		vires.spriteBatch:add(patternMyus, -64, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 64, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 192, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 320, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 448, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 576, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 704, -i * 128, 0, 1, 1, 0, 128)
		vires.spriteBatch:add(patternMyus, 832, -i * 128, 0, 1, 1, 0, 128)
		-- Aqua, bottom, X start at -64
		vires.spriteBatch:add(patternMyus, -64, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 64, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 192, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 320, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 448, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 576, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 704, 640 + i * 128)
		vires.spriteBatch:add(patternMyus, 832, 640 + i * 128)
	end
end

function vires.update(nw, nh)
	if not(vires.isInit) then return end

	if love._os == "iOS" then
		-- FIXME: use nw and nh specified instead of hardcoding this
		-- I can't figure out the math. Please send PR, thank you.
		local sx, sy
		sx, sy, nw, nh = love.window.getSafeArea()
		local sw, sh = nw - sx, nh - sy
		vires.data.scaleOverall = math.min(sw / vires.data.virtualW, sh / vires.data.virtualH)
		vires.data.offX = (sw - vires.data.scaleOverall * vires.data.virtualW) / 2 + sx
		vires.data.offY = (sh - vires.data.scaleOverall * vires.data.virtualH) / 2 + sy
	else
		vires.data.scaleOverall = math.min(nw / vires.data.virtualW, nh / vires.data.virtualH)
		vires.data.offX = (nw - vires.data.scaleOverall * vires.data.virtualW) / 2
		vires.data.offY = (nh - vires.data.scaleOverall * vires.data.virtualH) / 2
	end
end

function vires.screenToLogical(x, y)
	if not(vires.isInit) then return x, y end
	return (x - vires.data.offX) / vires.data.scaleOverall, (y - vires.data.offY) / vires.data.scaleOverall
end

function vires.logicalToScreen(x, y)
	if not(vires.isInit) then return x, y end
	return x * vires.data.scaleOverall + vires.data.offX, y * vires.data.scaleOverall + vires.data.offY
end

function vires.set()
	if not(vires.isInit) then return end
	love.graphics.translate(vires.data.offX, vires.data.offY)
	love.graphics.scale(vires.data.scaleOverall)
	love.graphics.draw(vires.spriteBatch)
end

function vires.unset()
	if not(vires.isInit) then return end
	love.graphics.scale(1/vires.data.scaleOverall)
	love.graphics.translate(-vires.data.offX, -vires.data.offY)
end

return vires
