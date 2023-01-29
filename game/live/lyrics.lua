-- Lyrics display
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local MainFont = require("main_font")

---@class Livesim2.Lyrics
local Lyrics = Luaoop.class("Livesim2.Lyrics")
local perZeroThree = 1/0.3

function Lyrics:__construct(srt)
	local font1, font2 = MainFont.get(24, 16)
	local timings = {}

	self.timings = timings
	self.active = nil
	self.elapsedTime = 0
	self.opacity = 0
	self.vanish = false

	for i = 1, #srt do
		local sub = srt[i]
		local t = {sub.start - 0.1, sub.stop - 0.1, nil, nil}

		local text1 = love.graphics.newText(font1)
		t[3] = text1
		text1:add({color.black, sub.text1}, 2, 2)
		text1:add({color.white, sub.text1}, 0, 0)

		if sub.text2 then
			local text2 = love.graphics.newText(font2)
			t[4] = text2
			text2:add({color.black, sub.text2}, 1, 1)
			text2:add({color.white, sub.text2}, 0, 0)
		end

		timings[#timings + 1] = t
	end
end

---@param dt number
function Lyrics:update(dt)
	self.elapsedTime = self.elapsedTime + dt

	local lyr = self.timings[1]
	if lyr and self.elapsedTime >= lyr[1] then
		self.active = lyr
		self.opacity = 0
		self.vanish = false

		for i = 2, #self.timings do
			self.timings[i - 1] = self.timings[i]
		end
		self.timings[#self.timings] = nil
	end

	if self.active and self.elapsedTime >= self.active[2] and self.vanish == false then
		self.vanish = true
	end

	self.opacity = math.max(math.min(self.opacity + (self.vanish and -dt or dt), 0.3), 0)

	if self.vanish and self.opacity == 0 then
		self.active = nil
	end
end

function Lyrics:draw()
	if self.active then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * perZeroThree))
		love.graphics.draw(self.active[3], 6, 590)
		if self.active[4] then
			love.graphics.draw(self.active[4], 6, 620)
		end
	end
end

---@cast Lyrics +fun(srt):Livesim2.Lyrics
return Lyrics
