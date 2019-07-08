-- Live Simulator: 2 v3.1 splash screen
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER

local love = require("love")
local timer = require("libs.hump.timer")

local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local util = require("util")

local splash = gamestate.create {
	fonts = {},
	images = {
		icon1 = {"new_icon1:assets/image/icon/new_icon_1024x1024_1.png", {mipmaps = true}},
		icon2 = {"new_icon2:assets/image/icon/new_icon_1024x1024_2.png", {mipmaps = true}},
		icon3 = {"new_icon3:assets/image/icon/new_icon_1024x1024_3.png", {mipmaps = true}}
	},
	audios = {},
}

local function done()
	gamestate.replace(loadingInstance.getInstance(), "mainMenu")
end

local function skip(self)
	local persist = self.persist

	if persist.skippable then
		self.data.timer:clear()
		persist.setShader = true
		-- Skip
		self.data.timer:tween(0.1, persist, {overallOpacity = 0}, "out-cubic")
		self.data.timer:after(0.1, done)
	end
end

function splash:load()
	-- Create version text
	if not(self.data.version) then
		local deprecate = util.compareLOVEVersion(11, 0) < 0 and "DEPRECATED!" or ""
		self.data.version = love.graphics.newText(
			love.graphics.newFont(11),
			string.format("v%s (%08d)\nPowered by LÖVE Framework (LÖVE %s) %s",
				DEPLS_VERSION, DEPLS_VERSION_NUMBER, love._version, deprecate
			)
		)
	end

	-- Create timer
	if not(self.data.timer) then
		self.data.timer = timer.new()
	end
end

function splash:start()
	local persist = self.persist
	local itimer = self.data.timer
	persist.icon1Scale = 0
	persist.icon2Scale = 0
	persist.icon3Scale = 0.73
	persist.icon3Draw = false
	persist.icon3Rot = math.pi/3
	persist.dot1Scale = 0
	persist.dot2Scale = 0
	persist.dot3Scale = 0
	persist.dot4Scale = 0
	persist.overallScale = 1
	persist.overallOpacity = 1
	persist.skippable = true

	itimer:script(function(wait)
		-- Delay it
		wait(0.1)

		-- Show core circle on the center
		itimer:tween(0.1, persist, {icon1Scale = 1}, "out-back")
		wait(0.1)

		-- Show first thick line circle (or whatever it names)
		itimer:tween(0.1, persist, {icon2Scale = 1}, "out-back")
		wait(0.1)

		-- Show two quarter line arc
		itimer:tween(0.1, persist, {icon3Scale = 1}, "out-cubic")
		-- Also rotate it to 0 degree
		itimer:tween(0.1, persist, {icon3Rot = 0}, "out-cubic")
		persist.icon3Draw = true
		wait(0.1)

		-- Show dots
		itimer:tween(0.07, persist, {dot1Scale = 1}, "out-back")
		wait(0.03)
		itimer:tween(0.07, persist, {dot2Scale = 1}, "out-back")
		wait(0.03)
		itimer:tween(0.07, persist, {dot3Scale = 1}, "out-back")
		wait(0.03)
		itimer:tween(0.07, persist, {dot4Scale = 1}, "out-back")
		wait(0.07)
		persist.skippable = false
		wait(0.05)

		-- Clear
		itimer:tween(0.05, persist, {overallScale = 0.8}, "out-sine")
		wait(0.05)
		itimer:tween(0.2, persist, {overallScale = 4, overallOpacity = 0}, "out-cubic")
		wait(0.2)
		return done()
	end)
end

function splash:update(dt)
	return self.data.timer:update(dt * 0.265)
end

function splash:draw()
	local persist = self.persist
	love.graphics.push("all")
	love.graphics.clear(color.hex6A6767)
	love.graphics.setColor(color.compat(255, 255, 255, persist.overallOpacity))

	-- Draw version text, always in origin
	do
		-- FIXME: It's not that efficient to do this here
		love.graphics.push()
		local a, _, _, d = 0, 0, love.graphics.getDimensions()
		if love.window.getSafeArea then
			a, _, _, d = love.window.getSafeArea()
		end
		love.graphics.origin()
		love.graphics.draw(self.data.version, a, d - self.data.version:getHeight() - 4)
		love.graphics.pop()
	end

	-- Setup transformation, let 480x320 our center
	love.graphics.translate(480, 320)
	-- Let the scale of the icon half of its intended (512x512 as opposed of 1024x1024)
	love.graphics.scale(0.5 * persist.overallScale)

	-- Draw dots. Dots are placed at radius 440 from circle center
	if persist.dot4Scale > 0 then
		local c, s = math.cos(math.pi * 4/10), math.sin(math.pi * 4/10)
		love.graphics.setColor(color.compat(104, 227, 46, persist.overallOpacity))
		love.graphics.circle("fill", 440 * s, -440 * c, persist.dot4Scale * 48)
		love.graphics.circle("fill", -440 * s, 440 * c, persist.dot4Scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, persist.dot4Scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, persist.dot4Scale * 48)
	end

	if persist.dot3Scale > 0 then
		local c, s = math.cos(math.pi * 3/10), math.sin(math.pi * 3/10)
		love.graphics.setColor(color.compat(255, 66, 66, persist.overallOpacity))
		love.graphics.circle("fill", 440 * s, -440 * c, persist.dot3Scale * 48)
		love.graphics.circle("fill", -440 * s, 440 * c, persist.dot3Scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, persist.dot3Scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, persist.dot3Scale * 48)
	end

	if persist.dot2Scale > 0 then
		local c, s = math.cos(math.pi * 2/10), math.sin(math.pi * 2/10)
		love.graphics.setColor(color.compat(56, 178, 246, persist.overallOpacity))
		love.graphics.circle("fill", 440 * s, -440 * c, persist.dot2Scale * 48)
		love.graphics.circle("fill", -440 * s, 440 * c, persist.dot2Scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, persist.dot2Scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, persist.dot2Scale * 48)
	end

	if persist.dot1Scale > 0 then
		local c, s = math.cos(math.pi * 1/10), math.sin(math.pi * 1/10)
		love.graphics.setColor(color.compat(249, 157, 49, persist.overallOpacity))
		love.graphics.circle("fill", 440 * s, -440 * c, persist.dot1Scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, persist.dot1Scale * 48)
		love.graphics.setColor(color.compat(230, 36, 199, persist.overallOpacity))
		love.graphics.circle("fill", -440 * s, 440 * c, persist.dot1Scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, persist.dot1Scale * 48)
	end

	love.graphics.setColor(color.compat(255, 255, 255, persist.overallOpacity))
	if persist.icon3Draw then
		-- Draw third quarter line arc (or whatever it names)
		love.graphics.draw(self.assets.images.icon3, 0, 0, persist.icon3Rot, persist.icon3Scale, persist.icon3Scale, 464, 464)
	end
	if persist.icon2Scale > 0 then
		-- Draw second think line circle
		love.graphics.draw(self.assets.images.icon2, 0, 0, 0, persist.icon2Scale, persist.icon2Scale, 344, 344)
	end
	if persist.icon1Scale > 0 then
		-- Draw core circle
		love.graphics.draw(self.assets.images.icon1, 0, 0, 0, persist.icon1Scale, persist.icon1Scale, 96, 96)
	end

	love.graphics.pop()
end

splash:registerEvent("keyreleased", skip)
splash:registerEvent("mousereleased", skip)

return splash
