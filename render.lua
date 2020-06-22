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

local fxaaShader = [[
/**
Basic FXAA implementation based on the code on geeks3d.com with the
modification that the texture2DLod stuff was removed since it's
unsupported by WebGL.
--
From:
https://github.com/mitsuhiko/webgl-meincraft
Copyright (c) 2011 by Armin Ronacher.
Some rights reserved.
Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:
	* Redistributions of source code must retain the above copyright
	  notice, this list of conditions and the following disclaimer.
	* Redistributions in binary form must reproduce the above
	  copyright notice, this list of conditions and the following
	  disclaimer in the documentation and/or other materials provided
	  with the distribution.
	* The names of the contributors may not be used to endorse or
	  promote products derived from this software without specific
	  prior written permission.
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/
/* Modified to be used with LOVE2D + Desktop OpenGL */
#ifdef OPENGL_ES
#	ifdef GL_FRAGMENT_PRECISION_HIGH
#		define HIGHEST_PRECISION highp
#	else
#		define HIGHEST_PRECISION mediump
#	endif	// GL_FRAGMENT_PRECISION_HIGH
precision HIGHEST_PRECISION float
precision HIGHEST_PRECISION vec2;
precision HIGHEST_PRECISION vec3;
precision HIGHEST_PRECISION vec4;
#endif	// OPENGL_ES
#ifndef FXAA_REDUCE_MIN
	#define FXAA_REDUCE_MIN   (1.0/ 64.0)
#endif
#ifndef FXAA_REDUCE_MUL
	#define FXAA_REDUCE_MUL   1.0
#endif
#ifndef FXAA_SPAN_MAX
	#define FXAA_SPAN_MAX     64.0
#endif
varying vec2 v_rgbNW;
varying vec2 v_rgbNE;
varying vec2 v_rgbSW;
varying vec2 v_rgbSE;
varying vec2 v_rgbM;
void texcoords(vec2 fragCoord, vec2 resolution,
			out vec2 v_rgbNW, out vec2 v_rgbNE,
			out vec2 v_rgbSW, out vec2 v_rgbSE,
			out vec2 v_rgbM) {
	vec2 inverseVP = 1.0 / resolution.xy;
	v_rgbNW = (fragCoord + vec2(-1.0, -1.0)) * inverseVP;
	v_rgbNE = (fragCoord + vec2(1.0, -1.0)) * inverseVP;
	v_rgbSW = (fragCoord + vec2(-1.0, 1.0)) * inverseVP;
	v_rgbSE = (fragCoord + vec2(1.0, 1.0)) * inverseVP;
	v_rgbM = vec2(fragCoord * inverseVP);
}
#if defined(PIXEL)
//optimized version for mobile, where dependent
//texture reads can be a bottleneck
vec4 fxaa(sampler2D tex, vec2 fragCoord, vec2 resolution,
			vec2 v_rgbNW, vec2 v_rgbNE,
			vec2 v_rgbSW, vec2 v_rgbSE,
			vec2 v_rgbM) {
	vec4 color;
	vec2 inverseVP = vec2(1.0 / resolution.x, 1.0 / resolution.y);
	vec3 rgbNW = texture2D(tex, v_rgbNW).xyz;
	vec3 rgbNE = texture2D(tex, v_rgbNE).xyz;
	vec3 rgbSW = texture2D(tex, v_rgbSW).xyz;
	vec3 rgbSE = texture2D(tex, v_rgbSE).xyz;
	vec4 texColor = texture2D(tex, v_rgbM);
	vec3 rgbM  = texColor.xyz;
	vec3 luma = vec3(0.299, 0.587, 0.114);
	float lumaNW = dot(rgbNW, luma);
	float lumaNE = dot(rgbNE, luma);
	float lumaSW = dot(rgbSW, luma);
	float lumaSE = dot(rgbSE, luma);
	float lumaM  = dot(rgbM,  luma);
	float lumaMin = min(lumaM, min(min(lumaNW, lumaNE), min(lumaSW, lumaSE)));
	float lumaMax = max(lumaM, max(max(lumaNW, lumaNE), max(lumaSW, lumaSE)));

	vec2 dir;
	dir.x = -((lumaNW + lumaNE) - (lumaSW + lumaSE));
	dir.y =  ((lumaNW + lumaSW) - (lumaNE + lumaSE));

	float dirReduce = max((lumaNW + lumaNE + lumaSW + lumaSE) *
						  (0.25 * FXAA_REDUCE_MUL), FXAA_REDUCE_MIN);

	float rcpDirMin = 1.0 / (min(abs(dir.x), abs(dir.y)) + dirReduce);
	dir = min(vec2(FXAA_SPAN_MAX, FXAA_SPAN_MAX),
			  max(vec2(-FXAA_SPAN_MAX, -FXAA_SPAN_MAX),
			  dir * rcpDirMin)) * inverseVP;

	vec3 rgbA = 0.5 * (
		texture2D(tex, fragCoord * inverseVP + dir * (1.0 / 3.0 - 0.5)).xyz +
		texture2D(tex, fragCoord * inverseVP + dir * (2.0 / 3.0 - 0.5)).xyz);
	vec3 rgbB = rgbA * 0.5 + 0.25 * (
		texture2D(tex, fragCoord * inverseVP + dir * -0.5).xyz +
		texture2D(tex, fragCoord * inverseVP + dir * 0.5).xyz);
	float lumaB = dot(rgbB, luma);
	if ((lumaB < lumaMin) || (lumaB > lumaMax))
		color = vec4(rgbA, texColor.a);
	else
		color = vec4(rgbB, texColor.a);
	return color;
}
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec2 resolution = vec2(love_ScreenSize.xy);
	vec2 fragCoord = texture_coords * resolution;
	/*texcoords(fragCoord, resolution, v_rgbNW, v_rgbNE, v_rgbSW, v_rgbSE, v_rgbM);*/
	return color * fxaa(texture, fragCoord, resolution, v_rgbNW, v_rgbNE, v_rgbSW, v_rgbSE, v_rgbM);
}
#elif defined(VERTEX)
vec4 position(mat4 clipSpaceFromLocal, vec4 localPosition) {
	vec2 resolution = love_ScreenSize.xy;
	vec2 fragCoord = VaryingTexCoord.xy * resolution;
	texcoords(fragCoord, resolution, v_rgbNW, v_rgbNE, v_rgbSW, v_rgbSE, v_rgbM);
	return clipSpaceFromLocal * localPosition;
}
#endif
]]

local function newFBO(w, h, f)
	if util.compareLOVEVersion(11, 0) >= 0 then
		return love.graphics.newCanvas(w, h, {format = f, dpiscale = 1})
	else
		return love.graphics.newCanvas(w, h, f)
	end
end

function render.initialize(renderObj)
	assert(hasffi, "FFI functionality needed to render")
	assert(ls2x.libav, "libav functionality missing")

	local fmt = love.graphics.getCanvasFormats().rgba16f and "rgba16f" or "rgba8"
	local width, height, fps = renderObj.width, renderObj.height, renderObj.fps

	log.debugf("render", "starting render, fps=%d, w=%d, h=%d, canvas=%s", fps, width, height, fmt)
	log.debugf("render", "video=%s audio=%s", renderObj.output, renderObj.audio)
	assert(ls2x.libav.startEncodingSession(renderObj.output, width, height, fps), "failed to start encoding session")
	audioManager.setRenderFramerate(fps)

	render.audio = assert(io.open(renderObj.audio, "wb"))
	render.audioLen = 0

	render.width, render.height = width, height
	render.step = 1/fps
	render.scaleOverall = math.min(width / vires.data.virtualW, height / vires.data.virtualH)
	render.offX = (width - render.scaleOverall * vires.data.virtualW) / 2
	render.offY = (height - render.scaleOverall * vires.data.virtualH) / 2
	render.image = love.image.newImageData(width, height, "rgba8")
	render.imagePointer = ffi.cast("uint8_t*", render.image:getPointer())
	render.framebuffer = newFBO(width, height, fmt)

	if util.compareLOVEVersion(11, 0) then
		render.MUL = 255
	else
		render.MUL = 1
	end

	if renderObj.fxaa then
		render.fxaa = love.graphics.newShader(fxaaShader)
		render.fxaaFramebuffer = newFBO(width, height, fmt)
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
	if a > 0 then
		local index = y * render.width + x
		-- Since it's premultipled alpha, we have to divide
		-- all color component by alpha value
		local alpha = a * render.MUL
		render.imagePointer[index * 4 + 0] = util.clamp((r * render.MUL) / alpha * 255 + 0.5, 0, 255)
		render.imagePointer[index * 4 + 1] = util.clamp((g * render.MUL) / alpha * 255 + 0.5, 0, 255)
		render.imagePointer[index * 4 + 2] = util.clamp((b * render.MUL) / alpha * 255 + 0.5, 0, 255)
		render.imagePointer[index * 4 + 3] = util.clamp(alpha + 0.5, 0, 255)
	end

	return r, g, b, a
end

function render.commit()
	if not(render.framebuffer) then return end
	love.graphics.pop()

	-- apply fxaa
	if render.fxaa then
		love.graphics.push("all")
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.setShader(render.fxaa)
		love.graphics.setCanvas(render.fxaaFramebuffer)
		love.graphics.clear()
		love.graphics.origin()
		love.graphics.draw(render.framebuffer)
		love.graphics.pop()
		render.framebuffer, render.fxaaFramebuffer = render.fxaaFramebuffer, render.framebuffer
	end

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
	num = num % 4294967296
	return string.char(
		num % 256,
		num / 256 % 256,
		num / 65536 % 256,
		num / 16777216
	)
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
