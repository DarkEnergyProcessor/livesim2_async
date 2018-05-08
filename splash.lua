-- Live Simulator: 2 Splash
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: ignore DEPLS_VERSION
-- luacheck: ignore DEPLS_VERSION_NUMBER

local splash = setmetatable({}, {__call = function(x) return x.new() end})
local speedFactor = 0.7
local love = require("love")
local tween = require("tween")
splash.__index = splash

splash.shader = love.graphics.newShader [[
extern number opacity;

vec4 effect(vec4 color, Image tex, vec2 tc, vec2 fc)
{
	vec4 x = Texel(tex, tc);
	return vec4(x.rgb, x.a * (tc.x >= opacity ? 0.0 : 1.0)) * color;
}
]]

-- Show icon in 250ms at +480+320 start at 0ms. linear
-- Rotate icon 720degree in 500ms and move to left at +166+320 start at 750ms. inOutCubic
-- Fade "Live Simulator: 2" string in 500ms at +285+284. linear
-- Delay 250ms.
-- Erase the icon and text in 250ms with shader. linear
function splash.new()
	local self = setmetatable({time = 0}, splash)

	-- Resource init
	self.icon = love.graphics.newImage("assets/image/icon/icon_1024x1024.png", {mipmaps = true})
	self.iconOpacity = 0
	self.iconPosX = 480
	self.iconRot = 0
	self.text = love.graphics.newText(love.graphics.newFont("MTLmr3m.ttf", 72))
	self.text:add({{0, 0, 0, 0.5}, "Live Simulator: 2"}, 2, 2)
	self.text:add({{0, 0, 0, 0.5}, "Live Simulator: 2"}, -2, -2)
	self.text:add({{1, 1, 1, 1}, "Live Simulator: 2"}, 0, 0)
	self.version = love.graphics.newText(
		love.graphics.newFont(16),
		string.format("v%s (%08d)\nPowered by LÖVE Framework (LÖVE %s)",
			DEPLS_VERSION, DEPLS_VERSION_NUMBER, love._version
		)
	)
	self.textOpacity = 0
	self.eraser = 1
	self.skipped = false
	self.done = false

	-- Tween
	self.iconOpacityTween = tween.new(250, self, {iconOpacity = 1})
	self.iconRotTween = tween.new(500, self, {iconRot = -4 * math.pi, iconPosX = 166}, "inOutCubic")
	self.textOpacityTween = tween.new(500, self, {textOpacity = 1})
	-- delay 250ms here
	self.eraserTween = tween.new(500, self, {eraser = -1})

	return self
end

function splash:update(dt)
	dt = dt * 1000 * speedFactor
	self.time = self.time + dt
	-- Update everything in backward, but not in else if
	if self.done then
		return -- no more
	end
	if self.time >= 1500 or self.skipped then
		if self.eraserTween:update(dt) then
			self.done = true
			if self.onDone then self.onDone() end
		end
	end
	if self.time >= 750 then
		self.textOpacityTween:update(dt)
	end
	if self.time >= 250 then
		self.iconRotTween:update(dt)
	end
	self.iconOpacityTween:update(dt)
end

function splash:draw()
	-- Clear screen
	love.graphics.clear(0, 187/255, 1, 1)

	if self.done then return end
	-- Set shader when necessary
	if self.time >= 1500 or self.skip then
		splash.shader:send("opacity", math.max(self.eraser, 0))
		love.graphics.setShader(splash.shader)
	end

	-- Draw icon
	love.graphics.setColor(1, 1, 1, self.iconOpacity)
	love.graphics.draw(self.icon, self.iconPosX, 320, self.iconRot, 128/1024, 128/1024, 512, 512)
	love.graphics.draw(self.version, 5, 600)
	-- Draw text
	love.graphics.setColor(1, 1, 1, self.textOpacity)
	love.graphics.draw(self.text, 285, 284)
	-- Clear shader
	love.graphics.setShader()
end

function splash:skip()
	if self.time < 1500 then self.skipped = true end
end

return splash
