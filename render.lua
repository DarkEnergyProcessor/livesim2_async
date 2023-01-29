-- Render function
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local hasffi, ffi = pcall(require, "ffi")
local AudioRender = require("libs.audiorender")
local ls2x = require("libs.ls2x")

local AudioManager = require("audio_manager")
local log = require("logging")
local Util = require("util")
local Vires = require("vires")

local Render = {
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

---@param w integer
---@param h integer
---@param f love.PixelFormat
---@return love.Canvas
local function newFBO(w, h, f)
	if Util.compareLOVEVersion(11, 0) >= 0 then
		return love.graphics.newCanvas(w, h, {format = f, dpiscale = 1})
	else
		return love.graphics.newCanvas(w, h, f)
	end
end

---@param n integer
local function dw2strle(n)
	return string.char(
		n % 256,
		math.floor(n / 256) % 256,
		math.floor(n / 65536) % 256,
		math.floor(n / 16777216) % 256
	)
end

---@param renderObj {width:integer,height:integer,fps:integer,output:string,audio:string,audioRenderOk:boolean,rate:integer,fxaa:boolean?}
function Render.initialize(renderObj)
	assert(hasffi, "FFI functionality needed to render")
	assert(ls2x.libav, "libav functionality missing")

	local fmt = love.graphics.getCanvasFormats().rgba16f and "rgba16f" or "rgba8"
	local width, height, fps = renderObj.width, renderObj.height, renderObj.fps
	local dpi = math.max(math.floor(height / 640 + 0.5), 1)

	log.debugf("render", "starting render, fps=%d, w=%d, h=%d, canvas=%s, dpiscale=%d", fps, width, height, fmt, dpi)
	log.debugf("render", "video=%s audio=%s", renderObj.output, renderObj.audio)
	Util.setDefaultFontDPIScale(dpi)
	assert(ls2x.libav.startEncodingSession(renderObj.output, width, height, fps), "failed to start encoding session")

	if renderObj.audioRenderOk then
		Render.audioUpdateNumerator = 0
		Render.audioUpdateDenominator = fps
		Render.audioRate = renderObj.rate
	else
		log.warnf("render", "forcing 48KHz and inferior audio mixing technique!")
		AudioManager.setRenderFramerate(fps)
		Render.audioRate = 48000
	end

	Render.useAudioRender = renderObj.audioRenderOk
	Render.audio = assert(io.open(renderObj.audio, "wb"))
	Render.audioLen = 0

	Render.width, Render.height = width, height
	Render.step = 1/fps
	Render.scaleOverall = math.min(width / Vires.data.virtualW, height / Vires.data.virtualH)
	Render.offX = (width - Render.scaleOverall * Vires.data.virtualW) / 2
	Render.offY = (height - Render.scaleOverall * Vires.data.virtualH) / 2
	Render.image = love.image.newImageData(width, height, "rgba8")
	Render.imagePointer = ffi.cast("uint8_t*", Render.image:getPointer())
	Render.framebuffer = newFBO(width, height, fmt)

	if Util.compareLOVEVersion(11, 0) then
		Render.MUL = 255
	else
		Render.MUL = 1
	end

	if renderObj.fxaa then
		Render.fxaa = love.graphics.newShader(fxaaShader)
		Render.fxaaFramebuffer = newFBO(width, height, fmt)
	end

	Render.audio:write(
		"RIFF",         -- Header
		"\0\0\0\0",     -- size
		"WAVEfmt ",     -- WAVE + format
		"\16\0\0\0",    -- Size of "fmt " chunk
		"\1\0",         -- Audio format (PCM)
		"\2\0",         -- Number of channels, stereo
		dw2strle(Render.audioRate),
		dw2strle(Render.audioRate * 2 --[[nchannel]] * 2 --[[sizeof(int16_t)]]),
		"\4\0",         -- NumChannels * BytesPerSample = 2*2
		"\16\0",        -- Bits per sample (16bits)
		"data",         -- data format
		"\0\0\0\0"      -- data size (set later)
	)
end

local temp = {stencil = true}
function Render.begin()
	if not(Render.framebuffer) then return end

	love.graphics.push("all")
	temp[1] = Render.framebuffer
	love.graphics.setCanvas(temp)
	love.graphics.clear()
	love.graphics.origin()
	love.graphics.translate(Render.offX, Render.offY)
	love.graphics.scale(Render.scaleOverall)
end

function Render.mapPixel(x, y, r, g, b, a)
	if a > 0 then
		local index = y * Render.width + x
		-- Since it's premultipled alpha, we have to divide
		-- all color component by alpha value
		local alpha = a * Render.MUL
		Render.imagePointer[index * 4 + 0] = Util.clamp((r * Render.MUL) / alpha * 255 + 0.5, 0, 255)
		Render.imagePointer[index * 4 + 1] = Util.clamp((g * Render.MUL) / alpha * 255 + 0.5, 0, 255)
		Render.imagePointer[index * 4 + 2] = Util.clamp((b * Render.MUL) / alpha * 255 + 0.5, 0, 255)
		Render.imagePointer[index * 4 + 3] = Util.clamp(alpha + 0.5, 0, 255)
	end

	return r, g, b, a
end

function Render.commit()
	if not(Render.framebuffer) then return end
	love.graphics.pop()

	-- apply fxaa
	if Render.fxaa then
		love.graphics.push("all")
		love.graphics.setBlendMode("alpha", "premultiplied")
		love.graphics.setShader(Render.fxaa)
		love.graphics.setCanvas(Render.fxaaFramebuffer)
		love.graphics.clear()
		love.graphics.origin()
		love.graphics.draw(Render.framebuffer)
		love.graphics.pop()
		Render.framebuffer, Render.fxaaFramebuffer = Render.fxaaFramebuffer, Render.framebuffer
	end

	local id = Render.framebuffer:newImageData()
	id:mapPixel(Render.mapPixel)
	Util.releaseObject(id)
	ls2x.libav.supplyVideoEncoder(Render.imagePointer)

	if Render.useAudioRender then
		-- Count audio update step
		Render.audioUpdateNumerator = Render.audioUpdateNumerator + Render.audioRate
		local smp = math.floor(Render.audioUpdateNumerator / Render.audioUpdateDenominator)
		Render.audioUpdateNumerator = Render.audioUpdateNumerator % Render.audioUpdateDenominator

		local sound = AudioRender.update(smp)
		Render.audio:write(sound)
		Render.audioLen = Render.audioLen + #sound / 2 / 2
	else
		local sd = AudioManager.updateRender()
		Render.audio:write(sd:getString())
		Render.audioLen = Render.audioLen + sd:getSampleCount()
	end

	-- draw
	local s = math.max(960 / Render.width, 640 / Render.height)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(Render.framebuffer, 480, 320, 0, s, s, Render.width * 0.5, Render.height * 0.5)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function Render.getStep()
	return Render.step
end

function Render.getDimensions()
	return Render.width, Render.height
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

function Render.done()
	if not(Render.framebuffer) then return end

	-- done encoding
	ls2x.libav.endEncodingSession()
	AudioManager.setRenderFramerate(0)
	-- finalize audio
	local cur = Render.audio:seek("cur")
	Render.audio:seek("set", 4)
	Render.audio:write(dwordu2string(cur - 4))
	Render.audio:seek("set", 40)
	Render.audio:write(dwordu2string(Render.audioLen * 4))
	Render.audio:close()

	Render.audio = nil
	Render.framebuffer = nil
	Render.imagePointer = nil
	Render.image = nil
end

return Render
