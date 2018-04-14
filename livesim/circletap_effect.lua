-- Circle tap effect routines using the new EffectPlayer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local math = require("math")
local DEPLS, AquaShine = ...
local CircleTapEffect = {Cache = {}}

local _common_meta = {__index = CircleTapEffect}

-- For obvious reason, this tap effect is incredibly slow in mobile devices.
-- So I need to perform some optimizations:
-- 1. Remove additional, stacked image and use *2 opacity
-- 2. Cache the object creation
-- 3. Use x*x*x*x*x instead of math.pow(x, 5) in interpolation calculation
-- Even with those optimization, using SD625, running BiA MASTER sometimes drop to 30FPS
local function createObject()
	local out = {r = 0, g = 0, b = 0, time = 0, pos = {0, 0}}
	out.spritebatch = love.graphics.newSpriteBatch(CircleTapEffect.Image, 4, "stream")
	out.stareff_sbid = out.spritebatch:add(CircleTapEffect.ef_316_000, 0, 0, 0, 2, 2, 50, 50)
	out.circle1_sbid = out.spritebatch:add(CircleTapEffect.ef_316_001, 0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle2_sbid = out.spritebatch:add(CircleTapEffect.ef_316_001, 0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle3_sbid = out.spritebatch:add(CircleTapEffect.ef_316_001, 0, 0, 0, 2.427, 2.427, 37.5, 37.5)

	CircleTapEffect.Cache[#CircleTapEffect.Cache + 1] = out
	return setmetatable(out, _common_meta)
end

local function init()
	-- Tap circle effect
	CircleTapEffect.Image = assert(AquaShine.LoadImage("assets/image/live/circleeffect.png") or nil)
	CircleTapEffect.ef_316_000 = love.graphics.newQuad(0, 0, 100, 100, 256, 128)
	CircleTapEffect.ef_316_001 = love.graphics.newQuad(128, 0, 75, 75, 256, 128)

	-- Tween data (begin, increment)
	CircleTapEffect.StarEffect = {{scale = 2, opacity = 1}, {scale = .6, opacity = -1}}
	CircleTapEffect.CircleEffect = {{scale = 2.427, opacity = 1}, {scale = 1.573, opacity = -1}}

	return CircleTapEffect
end

--! @brief Circletap aftertap effect initialize function.
--! @param x The x position relative to center of the image
--! @param y The y position relative to center of the image
--! @param r The RGB red value. Defaults to 255
--! @param g The RGB green value. Defaults to 255
--! @param b The RGB blue value. Defaults to 255
function CircleTapEffect.Create(x, y, r, g, b)
	local out

	-- Find cache
	for i = 1, #CircleTapEffect.Cache do
		local a = CircleTapEffect.Cache[i]
		if a.time >= 800 then
			out = a
			break
		end
	end

	out = out or createObject()
	out.r, out.g, out.b = r, g, b
	out.pos[1], out.pos[2] = x, y
	out.time = 0

	return out
end

local function pow5(n)
	return n * n * n * n * n
end

function CircleTapEffect.Update(this, deltaT)
	this.time = this.time + deltaT
	return CircleTapEffect.ActualUpdate(this)
end

function CircleTapEffect.ActualUpdate(this)
	local ntime = math.min(this.time / 800, 1)
	local scale = CircleTapEffect.StarEffect[2].scale * (pow5(ntime - 1) + 1) + CircleTapEffect.StarEffect[1].scale
	local opacity = CircleTapEffect.StarEffect[2].opacity * (pow5(ntime - 1) + 1) + CircleTapEffect.StarEffect[1].opacity
	this.spritebatch:setColor(this.r, this.g, this.b, opacity)
	this.spritebatch:set(this.stareff_sbid, CircleTapEffect.ef_316_000, 0, 0, 0, scale, scale, 50, 50)

	ntime = math.min(this.time / 200, 1)
	scale = CircleTapEffect.CircleEffect[2].scale * (pow5(ntime - 1) + 1) + CircleTapEffect.CircleEffect[1].scale
	opacity = CircleTapEffect.CircleEffect[2].opacity * (pow5(ntime - 1) + 1) + CircleTapEffect.CircleEffect[1].opacity
	this.spritebatch:setColor(this.r, this.g, this.b, opacity * 2)
	this.spritebatch:set(this.circle1_sbid, CircleTapEffect.ef_316_001, 0, 0, 0, scale, scale, 37.5, 37.5)

	ntime = math.min(this.time / 450, 1)
	scale = CircleTapEffect.CircleEffect[2].scale * (pow5(ntime - 1) + 1) + CircleTapEffect.CircleEffect[1].scale
	opacity = CircleTapEffect.CircleEffect[2].opacity * (pow5(ntime - 1) + 1) + CircleTapEffect.CircleEffect[1].opacity
	this.spritebatch:setColor(this.r, this.g, this.b, opacity * 2)
	this.spritebatch:set(this.circle2_sbid, CircleTapEffect.ef_316_001, 0, 0, 0, scale, scale, 37.5, 37.5)

	ntime = math.min(this.time / 700, 1)
	scale = CircleTapEffect.CircleEffect[2].scale * (pow5(ntime - 1) + 1) + CircleTapEffect.CircleEffect[1].scale
	opacity = CircleTapEffect.CircleEffect[2].opacity * (pow5(ntime - 1) + 1) + CircleTapEffect.CircleEffect[1].opacity
	this.spritebatch:setColor(this.r, this.g, this.b, opacity * 2)
	this.spritebatch:set(this.circle3_sbid, CircleTapEffect.ef_316_001, 0, 0, 0, scale, scale, 37.5, 37.5)

	return this.time >= 800
end

function CircleTapEffect.Draw(this)
	love.graphics.setColor(this.r, this.g, this.b, DEPLS.LiveOpacity)
	love.graphics.draw(this.spritebatch, this.pos[1], this.pos[2])
end

return init()
