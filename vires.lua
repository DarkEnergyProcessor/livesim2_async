-- Virtual Resolution System
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local vires = {
	data = {
		virtualW = 0,
		virtualH = 0,
		screenX = 0,
		screenY = 0,
		offX = 0,
		offY = 0,
		scaleOverall = 1
	},
	isInit = false
}

function vires.init(width, height)
	if vires.isInit then return end
	vires.data.virtualW, vires.data.virtualH = width, height
	vires.data.screenX, vires.data.screenY = width, height
	vires.isInit = true
end

function vires.update(nw, nh)
	if not(vires.isInit) then return end

	vires.data.screenX, vires.data.screenY = nw, nh
	vires.data.scaleOverall = math.min(nw / vires.data.virtualW, nh / vires.data.virtualH)
	vires.data.offX = (nw - vires.data.scaleOverall * vires.data.virtualW) / 2
	vires.data.offY = (nh - vires.data.scaleOverall * vires.data.virtualH) / 2
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
end

function vires.unset()
	if not(vires.isInit) then return end
	love.graphics.scale(1/vires.data.scaleOverall)
	love.graphics.translate(-vires.data.offX, -vires.data.offY)
end

return vires
