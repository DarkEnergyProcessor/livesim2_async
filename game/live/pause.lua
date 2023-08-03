-- Pause screen
-- Part of Live Simulator: 2
-- see copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local MainFont = require("main_font")
local Util = require("util")
local L = require("language")

---@class Livesim2.Pause: IUpdateable, IDrawable
local Pause = Luaoop.class("Livesim2.Pause")

---must be in async
---@param callbacks {resume:function,quit:function,restart:function,failAnimation:IUpdateable|IDrawable}
---@param replay string?
function Pause:__construct(callbacks, opaque, replay)
	self.font, self.mainCounterFont = MainFont.get(36, 72)
	self.timer = math.huge
	self.paused = false
	self.callback = callbacks
	self.opaque = opaque
	self.beatmapName = ""
	self.displayText = ""
	self.failedTimer = 3

	if replay then
		self.replayString = L("livesim2:pause:replay", {name = Util.basename(replay)})
	else
		self.replayString = ""
	end
end

---@param dt number
function Pause:update(dt)
	if self.paused then
		if self.isFailed then
			self.callback.failAnimation:update(dt * 1000)
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

function Pause:_drawCounter()
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
function Pause:_drawPause()
	-- always follow this coordinate:
	-- x = 416
	-- y = 228 + i * 72 (where i starts at 1)
	local w

	love.graphics.setFont(self.mainCounterFont)
	if self.isFailed then
		local fail = L"livesim2:pause:fail"
		w = self.mainCounterFont:getWidth(fail)
		love.graphics.setColor(color.orangeRed)
		love.graphics.print(fail, 480-w*0.5, 128)
	else
		local paused = L"livesim2:pause:pause"
		w = self.mainCounterFont:getWidth(paused)
		love.graphics.setColor(color.white)
		love.graphics.print(paused, 480-w*0.5, 128)
	end

	w = self.font:getWidth(self.displayText)
	love.graphics.setFont(self.font)
	--love.graphics.print(self.displayText, 480, 192, 0, 1, 1, w * 0.5, 0)
	love.graphics.printf(self.displayText, 480 - w * 0.5, 192, w, "center")

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

function Pause:_drawFailed()
	return self.callback.failAnimation:draw(480, 320)
end

function Pause:draw()
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

---@param name string
---@param fail boolean
function Pause:pause(name, fail)
	self.paused = true
	self.isFailed = not(not(fail))
	self.beatmapName = name or self.beatmapName
	self.displayText = self.beatmapName.."\n"..self.replayString
end

function Pause:isPaused()
	return self.paused
end

---@param x number
---@param y number
function Pause:mouseReleased(x, y)
	if self.paused and self.timer == math.huge then
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

function Pause:fastResume()
	if self.paused then
		self.callback.resume(self.opaque)
		self.timer = math.huge
		self.paused = false
	end
end

---@cast Pause +fun(callbacks:{resume:function,quit:function,restart:function,failAnimation:IUpdateable|IDrawable},opaque:any,replay:string?):Livesim2.Pause
return Pause
