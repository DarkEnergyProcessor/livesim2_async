-- Pause screen
-- Part of Live Simulator: 2
-- see copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local Yohane = require("libs.Yohane")

local color = require("color")
local mainFont = require("font")
local L = require("language")

local pause = Luaoop.class("livesim2.Pause")

-- must be in async
-- callbacks must be table: resume, quit, restart
function pause:__construct(callbacks, opaque)
	self.font = mainFont.get(36)
	self.mainCounterFont = mainFont.get(72)
	self.timer = math.huge
	self.paused = false
	self.callback = callbacks
	self.opaque = opaque
	self.beatmapName = ""
	self.failedAnimation = Yohane.newFlashFromFilename("flash/live_gameover.flsh", "ef_312")
	self.failedTimer = 3
end

function pause:update(dt)
	if self.paused then
		if self.isFailed then
			self.failedAnimation:update(dt * 1000)
			self.failedTimer = math.max(self.failedTimer - dt, 0)
		end

		self.timer = self.timer - dt

		if self.timer <= 0 then
			self.callback.resume(self.opaque)
			self.timer = math.huge
			self.paused = false
		end
	end
end

function pause:_drawCounter()
	local fract = self.timer % 1
	local fractStr = string.format(".%03d", math.min(fract * 1000, 999))
	local whole = tostring(math.ceil(self.timer))
	local s = (1 - fract) + 1

	local w = self.mainCounterFont:getWidth(whole)
	love.graphics.setFont(self.mainCounterFont)
	love.graphics.setColor(color.compat(255, 255, 255, fract))
	love.graphics.print(whole, 480, 270, 0, s, s, w * 0.5, 36)
	love.graphics.setColor(color.white)
	love.graphics.print(whole, 480, 234, 0, 1, 1, w * 0.5, 0)
	w = self.font:getWidth(fractStr)
	love.graphics.setFont(self.font)
	love.graphics.print(fractStr, 480, 302, 0, 1, 1, w * 0.5, 0)
	local resumeIn = L"livesim2:pause:resumeIn"
	w = self.font:getWidth(resumeIn)
	love.graphics.print(resumeIn, 480-w*0.5, 192)
end

local buttons = {
	{
		display = L"livesim2:pause:resume",
		callback = function(pauseObject)
			pauseObject.timer = 3
		end,
		color = {color.get(0, 138, 255, 0.5)}
	},
	{
		display = L"livesim2:pause:quit",
		callback = "quit",
		color = {color.get(251, 148, 0, 0.5)}
	},
	{
		display = L"livesim2:pause:restart",
		callback = "restart",
		color = {color.get(255, 28, 124, 0.5)}
	}
}
function pause:_drawPause()
	-- always follow this coordinate:
	-- x = 416
	-- y = 228 + i * 72 (where i starts at 1)
	local w

	love.graphics.setFont(self.mainCounterFont)
	if self.isFailed then
		local fail = L"livesim2:pause:fail"
		w = self.mainCounterFont:getWidth(fail)
		love.graphics.setColor(color.orangeRed)
		love.graphics.print("Failed", 480-w*0.5, 128)
	else
		local paused = L"livesim2:pause:pause"
		w = self.mainCounterFont:getWidth(paused)
		love.graphics.setColor(color.white)
		love.graphics.print(paused, 480-w*0.5, 128)
	end

	w = self.font:getWidth(self.beatmapName)
	love.graphics.setFont(self.font)
	love.graphics.print(self.beatmapName, 480, 192, 0, 1, 1, w * 0.5, 0)

	for i = (self.isFailed and 2 or 1), #buttons do
		local b = buttons[i]
		local y = 228 + i * 72
		w = self.font:getWidth(b.display)

		love.graphics.setColor(b.color)
		love.graphics.rectangle("fill", 384, y, 192, 48)
		love.graphics.setColor(color.white52PT)
		love.graphics.print(b.display, 480, y + 5, 0, 1, 1, w * 0.5, 0)
	end
end

function pause:_drawFailed()
	return self.failedAnimation:draw(480, 320)
end

function pause:draw()
	if self.paused then
		-- draw black overlay
		love.graphics.push()
		love.graphics.origin()
		love.graphics.setColor(color.black75PT)
		love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
		love.graphics.pop()

		if self.timer == math.huge then
			if self.isFailed and self.failedTimer > 0 then
				return self:_drawFailed()
			else
				return self:_drawPause()
			end
		else
			return self:_drawCounter()
		end
	end
end

function pause:pause(name, fail)
	self.paused = true
	self.isFailed = not(not(fail))
	self.beatmapName = name or self.beatmapName
end

function pause:isPaused()
	return self.paused
end

function pause:mouseReleased(x, y)
	if self.paused then
		local maxy = 300 + #buttons * 72
		if x >= 384 and y >= 300 and x < 576 and y < maxy then
			local index = (y - 300) / 72
			if index % 1 < 48/72 then -- button only has height of 48px
				-- direct indexing
				index = math.floor(index)
				if index == 0 and self.isFailed then return end -- no resume

				local button = buttons[index + 1]
				if type(button.callback) == "function" then
					button.callback(self)
				else
					self.callback[button.callback](self.opaque)
				end
			end
		end
	end
end

return pause
