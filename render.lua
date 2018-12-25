-- Render function
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local hasffi, ffi = pcall(require, "ffi")
local ls2x = require("libs.ls2x")

local audioManager = require("audio_manager")
local log = require("logging")
local util = require("util")
local vires = require("vires")

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

function render.initialize(out, audio, width, height)
	assert(hasffi, "FFI functionality needed to render")
	assert(ls2x.libav, "libav functionality missing")
	local fmt = love.graphics.getCanvasFormats().rgba16f and "rgba16f" or "rgba8"
	log.debugf("render", "starting render, fps=60, w=%d, h=%d, canvas=%s", width, height, fmt)
	log.debugf("render", "video=%s audio=%s", out, audio)
	ls2x.libav.startEncodingSession(out, width, height, 60)
	audioManager.setRenderFramerate(60)

	render.audio = assert(io.open(audio, "wb"))
	render.audioLen = 0

	render.width, render.height = width, height
	render.scaleOverall = math.min(width / vires.data.virtualW, height / vires.data.virtualH)
	render.offX = (width - render.scaleOverall * vires.data.virtualW) / 2
	render.offY = (height - render.scaleOverall * vires.data.virtualH) / 2
	render.image = love.image.newImageData(width, height, "rgba8")
	render.imagePointer = ffi.cast("uint8_t*", render.image:getPointer())
	if util.compareLOVEVersion(11, 0) then
		render.framebuffer = love.graphics.newCanvas(width, height, {format = fmt})
		render.MUL = 255
	else
		render.framebuffer = love.graphics.newCanvas(width, height, fmt)
		render.MUL = 1
	end

	render.audio:write(
		"RIFF",         -- Header
		"\0\0\0\0",     -- size
		"WAVEfmt ",     -- WAVE + format
		"\16\0\0\0",    -- Size of "fmt " chunk
		"\1\0",         -- Audio format (PCM)
		"\2\0",         -- Number of channels, stereo
		"\128\187\0\0", -- Sample rate (48000)
		"\0\238\2\0",   -- SampleRate * NumChannels * BytesPerSample = 48000*2*2
		"\4\0",         -- NumChannels * BytesPerSample = 2*2
		"\16\0",        -- Bits per sample (16bits)
		"data",         -- data format
		"\0\0\0\0"      -- data size (set later)
	)
end

local temp = {stencil = true}
function render.begin()
	if not(render.framebuffer) then return end

	love.graphics.push("all")
	temp[1] = render.framebuffer
	love.graphics.setCanvas(temp)
	love.graphics.clear()
	love.graphics.origin()
	love.graphics.translate(render.offX, render.offY)
	love.graphics.scale(render.scaleOverall)
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
	if not(render.framebuffer) then return end
	love.graphics.pop()

	local id = render.framebuffer:newImageData()
	id:mapPixel(render.mapPixel)
	util.releaseObject(id)
	ls2x.libav.supplyVideoEncoder(render.imagePointer)
	local sd = audioManager.updateRender()
	render.audio:write(sd:getString())
	render.audioLen = render.audioLen + sd:getSampleCount()

	-- draw
	local s = math.max(960 / render.width, 640 / render.height)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(render.framebuffer, 480, 320, 0, s, s, render.width * 0.5, render.height * 0.5)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function render.getStep()
	return render.step
end

function render.getDimensions()
	return render.width, render.height
end

local function dwordu2string(num)
	local b = {}
	b[1] = string.char(bit.band(num, 0xFF))
	b[2] = string.char(bit.rshift(bit.band(num, 0xFF00), 8))
	b[3] = string.char(bit.rshift(bit.band(num, 0xFF0000), 16))
	b[4] = string.char(bit.rshift(bit.band(num, 0xFF000000), 24))

	return table.concat(b)
end

function render.done()
	if not(render.framebuffer) then return end

	-- done encoding
	ls2x.libav.endEncodingSession()
	audioManager.setRenderFramerate(0)
	-- finalize audio
	local cur = render.audio:seek("cur")
	render.audio:seek("set", 4)
	render.audio:write(dwordu2string(cur - 4))
	render.audio:seek("set", 40)
	render.audio:write(dwordu2string(render.audioLen * 4))
	render.audio:close()

	render.audio = nil
	render.framebuffer = nil
	render.imagePointer = nil
	render.image = nil
end

return render
