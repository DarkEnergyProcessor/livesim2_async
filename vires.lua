-- Virtual Resolution System
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local NLay = require("libs.nlay")

local Vires = {
	data = {
		virtualW = 0,
		virtualH = 0,
		offX = 0,
		offY = 0,
		scaleOverall = 1
	},
	isInit = false
}

function Vires.init(width, height)
	if Vires.isInit then return end
	Vires.data.virtualW, Vires.data.virtualH = width, height
	Vires.isInit = true

	-- Create background sprite batch.
	-- Cannot use async here because it's not available.
	local thickness = 3
	Vires.spriteBatch = love.graphics.newSpriteBatch(
		love.graphics.newImage("assets/image/background/pattern.png"),
		thickness * 26
	)
	local patternMyus = love.graphics.newQuad(0, 0, 128, 128, 256, 128)
	local patternAqua = love.graphics.newQuad(128, 0, 128, 128, 256, 128)

	for i = 0, thickness-1 do
		-- Myus, left, Y start at 0
		Vires.spriteBatch:add(patternMyus, -i * 128, 0, 0, 1, 1, 128, 0)
		Vires.spriteBatch:add(patternMyus, -i * 128, 128, 0, 1, 1, 128, 0)
		Vires.spriteBatch:add(patternMyus, -i * 128, 256, 0, 1, 1, 128, 0)
		Vires.spriteBatch:add(patternMyus, -i * 128, 384, 0, 1, 1, 128, 0)
		Vires.spriteBatch:add(patternMyus, -i * 128, 512, 0, 1, 1, 128, 0)
		-- Aqua, right, Y start at 0
		Vires.spriteBatch:add(patternAqua, 960 + i * 128, 0)
		Vires.spriteBatch:add(patternAqua, 960 + i * 128, 128)
		Vires.spriteBatch:add(patternAqua, 960 + i * 128, 256)
		Vires.spriteBatch:add(patternAqua, 960 + i * 128, 384)
		Vires.spriteBatch:add(patternAqua, 960 + i * 128, 512)
		-- Myus, top, X start at -64
		Vires.spriteBatch:add(patternMyus, -64, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 64, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 192, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 320, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 448, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 576, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 704, -i * 128, 0, 1, 1, 0, 128)
		Vires.spriteBatch:add(patternMyus, 832, -i * 128, 0, 1, 1, 0, 128)
		-- Aqua, bottom, X start at -64
		Vires.spriteBatch:add(patternMyus, -64, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 64, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 192, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 320, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 448, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 576, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 704, 640 + i * 128)
		Vires.spriteBatch:add(patternMyus, 832, 640 + i * 128)
	end

	NLay.update(0, 0, Vires.data.virtualW, Vires.data.virtualH)
end

function Vires.update(nw, nh)
	if not(Vires.isInit) then return end

	Vires.data.scaleOverall = math.min(nw / Vires.data.virtualW, nh / Vires.data.virtualH)
	Vires.data.offX = (nw - Vires.data.scaleOverall * Vires.data.virtualW) / 2
	Vires.data.offY = (nh - Vires.data.scaleOverall * Vires.data.virtualH) / 2
end

function Vires.screenToLogical(x, y)
	if not(Vires.isInit) then return x, y end
	return (x - Vires.data.offX) / Vires.data.scaleOverall, (y - Vires.data.offY) / Vires.data.scaleOverall
end

function Vires.logicalToScreen(x, y)
	if not(Vires.isInit) then return x, y end
	return x * Vires.data.scaleOverall + Vires.data.offX, y * Vires.data.scaleOverall + Vires.data.offY
end

function Vires.getScaling()
	return Vires.data.scaleOverall
end

function Vires.getOffset()
	return Vires.data.offX, Vires.data.offY
end

function Vires.set()
	if not(Vires.isInit) then return end
	love.graphics.translate(Vires.data.offX, Vires.data.offY)
	love.graphics.scale(Vires.data.scaleOverall)
	love.graphics.draw(Vires.spriteBatch)
end

function Vires.unset()
	if not(Vires.isInit) then return end
	love.graphics.scale(1/Vires.data.scaleOverall)
	love.graphics.translate(-Vires.data.offX, -Vires.data.offY)
end

return Vires
