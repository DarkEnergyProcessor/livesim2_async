-- Circle tap effect routines using the new EffectPlayer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = require("love")
local DEPLS, AquaShine = ...
local CircleTapEffect = {}
local CircleDest = {scale = 4, opacity = 0}

local _common_meta = {__index = CircleTapEffect}

local function init()
	-- Tap circle effect
	CircleTapEffect.ef_316_000 = AquaShine.LoadImage("assets/image/live/ef_316_000.png")
	CircleTapEffect.ef_316_001 = AquaShine.LoadImage("assets/image/live/ef_316_001.png")

	return CircleTapEffect
end

--! @brief Circletap aftertap effect initialize function.
--! @param x The x position relative to center of the image
--! @param y The y position relative to center of the image
--! @param r The RGB red value. Defaults to 255
--! @param g The RGB green value. Defaults to 255
--! @param b The RGB blue value. Defaults to 255
function CircleTapEffect.Create(x, y, r, g, b)
	local out = {r = r, g = g, b = b}

	out.stareff_data = {scale = 2, opacity = 1}
	out.circle1_data = {scale = 2.427, opacity = 1}
	out.circle2_data = {scale = 2.427, opacity = 1}
	out.circle3_data = {scale = 2.427, opacity = 1}
	out.spritebatch = love.graphics.newSpriteBatch(CircleTapEffect.ef_316_001, 10, "stream")
	out.stareff_tween = tween.new(800, out.stareff_data, {scale = 2.6, opacity = 0}, "outQuint")
	out.circle1_tween = tween.new(200, out.circle1_data, CircleDest, "outQuint")
	out.circle2_tween = tween.new(450, out.circle2_data, CircleDest, "outQuint")
	out.circle3_tween = tween.new(700, out.circle3_data, CircleDest, "outQuint")
	out.circle1_data.sbid1 = out.spritebatch:add(0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle2_data.sbid1 = out.spritebatch:add(0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle3_data.sbid1 = out.spritebatch:add(0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle1_data.sbid2 = out.spritebatch:add(0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle2_data.sbid2 = out.spritebatch:add(0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.circle3_data.sbid2 = out.spritebatch:add(0, 0, 0, 2.427, 2.427, 37.5, 37.5)
	out.pos = {x, y}

	return setmetatable(out, _common_meta)
end

function CircleTapEffect.Update(this, deltaT)
	local still_has_render = this.stareff_tween:update(deltaT)
	still_has_render = this.circle1_tween:update(deltaT) and still_has_render
	still_has_render = this.circle2_tween:update(deltaT) and still_has_render
	still_has_render = this.circle3_tween:update(deltaT) and still_has_render

	this.spritebatch:setColor(this.r, this.g, this.b, this.circle1_data.opacity)
	this.spritebatch:set(this.circle1_data.sbid1, 0, 0, 0, this.circle1_data.scale, this.circle1_data.scale, 37.5, 37.5)
	this.spritebatch:set(this.circle1_data.sbid2, 0, 0, 0, this.circle1_data.scale, this.circle1_data.scale, 37.5, 37.5)
	this.spritebatch:setColor(this.r, this.g, this.b, this.circle2_data.opacity)
	this.spritebatch:set(this.circle2_data.sbid1, 0, 0, 0, this.circle2_data.scale, this.circle2_data.scale, 37.5, 37.5)
	this.spritebatch:set(this.circle2_data.sbid2, 0, 0, 0, this.circle2_data.scale, this.circle2_data.scale, 37.5, 37.5)
	this.spritebatch:setColor(this.r, this.g, this.b, this.circle3_data.opacity)
	this.spritebatch:set(this.circle3_data.sbid1, 0, 0, 0, this.circle3_data.scale, this.circle3_data.scale, 37.5, 37.5)
	this.spritebatch:set(this.circle3_data.sbid2, 0, 0, 0, this.circle3_data.scale, this.circle3_data.scale, 37.5, 37.5)

	return still_has_render
end

function CircleTapEffect.Draw(this)
	love.graphics.setColor(this.r, this.g, this.b, this.stareff_data.opacity * DEPLS.LiveOpacity)
	love.graphics.draw(CircleTapEffect.ef_316_000, this.pos[1], this.pos[2], 0, this.stareff_data.scale, this.stareff_data.scale, 50, 50)
	love.graphics.setColor(this.r, this.g, this.b, DEPLS.LiveOpacity)
	love.graphics.draw(this.spritebatch, this.pos[1], this.pos[2])
	love.graphics.setColor(255, 255, 255)
end

return init()
