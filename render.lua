-- Render function
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local hasffi, ffi = pcall(require, "ffi")
local ls2x = require("libs.ls2x")

local audioManager = require("audio_manager")
local util = require("util")
local render = {
	width = 0, height = 0,
	framerate = 60,
	step = 1/60,
	offX = 0,
	offY = 0,
	scaleOverall = 1,
	MUL = 1,
	framebuffer = nil,
	image = nil,
	imagePointer = nil,
}

function render.initialize(out, width, height)
	assert(hasffi, "FFI functionality needed to render")
	local fmt = love.graphics.getCanvasFormats().rgba16f and "rgba16f" or "rgba8"
	ls2x.libav.startEncodingSession(out, width, height, 60)
	audioManager.setRenderFramerate(60)
	render.width, render.height = width, height
	render.scaleOverall = math.min(width / 960, height / 640)
	render.offX = (width - render.scaleOverall * 960) / 2
	render.offY = (height - render.scaleOverall * 640) / 2
	render.image = love.image.newImageData(width, height, "rgba8")
	render.imagePointer = ffi.cast("uint8_t*", render.image:getPointer())
	if util.compareLOVEVersion(11, 0) then
		render.framebuffer = love.graphics.newCanvas(width, height, {format = fmt})
		render.MUL = 255
	else
		render.framebuffer = love.graphics.newCanvas(width, height, fmt)
		render.MUL = 1
	end
end

function render.begin()
	love.graphics.push("all")
	love.graphics.setCanvas(render.framebuffer)
	love.graphics.clear()
	love.graphics.origin()
	love.graphics.translate(render.data.offX, render.data.offY)
	love.graphics.scale(render.data.scaleOverall)
end

function render.mapPixel(x, y, r, g, b, a)
	local index = y * render.width + x
	-- Since it's premultipled alpha, we have to divide
	-- all color component by alpha value
	local alpha = a * render.MUL
	render.imagePointer[index * 4 + 0] = util.clamp((r * render.MUL) / alpha * 255 + 0.5, 0, 255)
	render.imagePointer[index * 4 + 1] = util.clamp((g * render.MUL) / alpha * 255 + 0.5, 0, 255)
	render.imagePointer[index * 4 + 2] = util.clamp((b * render.MUL) / alpha * 255 + 0.5, 0, 255)
	render.imagePointer[index * 4 + 3] = util.clamp(alpha + 0.5, 0, 255)
	return r, g, b, a
end

function render.commit()
	love.graphics.pop()

	local id = render.framebuffer:newImageData()
	id:mapPixel(render.mapPixel)
	util.releaseObject(id)
	ls2x.libav.supplyEncoder(render.imagePointer)

	-- draw
	local s = math.max(960 / render.width, 640 / render.height)
	love.graphics.setBlendMode("alpha", "premultipled")
	love.graphics.draw(render.framebuffer, 480, 360, 0, s, s, render.width * 0.5, render.height * 0.5)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function render.getStep()
	return render.step
end

function render.done()
	ls2x.libav.endEncodingSession()
	render.framebuffer = nil
	render.imagePointer = nil
	render.image = nil
end

return render
