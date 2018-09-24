-- Pause screen
-- Part of Live Simulator: 2
-- see copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local assetCache = require("asset_cache")
local color = require("color")

local pause = Luaoop.class("livesim2.Pause")

-- must be in async
-- callbacks must be table: resume, quit, restart
function pause:__construct(callbacks, opaque)
	self.font = assetCache.loadFont("fonts/MTLmr3m.ttf", 36)
	self.mainCounterFont = assetCache.loadFont("fonts/MTLmr3m.ttf", 72)
	self.timer = math.huge
	self.paused = false
	self.callback = callbacks
	self.opaque = opaque
	self.beatmapName = ""
end

function pause:update(dt)
	if self.paused then
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
	love.graphics.print("Resume in", 411, 192)
end

local buttons = {
	{
		display = "Resume",
		callback = function(pauseObject)
			pauseObject.timer = 3
		end,
		color = {color.get(0, 138, 255, 0.5)}
	},
	{
		display = "Quit",
		callback = "quit",
		color = {color.get(251, 148, 0, 0.5)}
	},
	{
		display = "Restart",
		callback = "restart",
		color = {color.get(255, 28, 124, 0.5)}
	}
}
function pause:_drawPause()
	-- always follow this coordinate:
	-- x = 416
	-- y = 228 + i * 72 (where i starts at 1)
	local w = self.font:getWidth(self.beatmapName)
	love.graphics.setColor(color.white)
	love.graphics.setFont(self.mainCounterFont)
	love.graphics.print("Paused", 372, 128)
	love.graphics.setFont(self.font)
	love.graphics.print(self.beatmapName, 480, 192, 0, 1, 1, w * 0.5, 0)

	for i = 1, #buttons do
		local b = buttons[i]
		local y = 228 + i * 72
		w = self.font:getWidth(b.display)

		love.graphics.setColor(b.color)
		love.graphics.rectangle("fill", 416, y, 128, 48)
		love.graphics.setColor(color.white50PT)
		love.graphics.print(b.display, 480, y + 5, 0, 1, 1, w * 0.5, 0)
	end
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
			return self:_drawPause()
		else
			return self:_drawCounter()
		end
	end
end

function pause:pause(name)
	self.paused = true
	self.beatmapName = name or self.beatmapName
end

function pause:isPaused()
	return self.paused
end

function pause:mouseReleased(x, y)
	if self.paused then
		local maxy = 300 + #buttons * 72
		if x >= 416 and y >= 300 and x < 544 and y < maxy then
			local index = (y - 300) / 72
			if index % 1 < 48/72 then -- button only has size of 48px
				-- direct indexing
				local button = buttons[math.floor(index) + 1]
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
