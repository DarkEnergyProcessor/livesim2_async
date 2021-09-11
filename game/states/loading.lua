-- Loading screen (v3.1)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- Loading screen is a special gamestate.
-- Their :start and :exit method are only called
-- once, at game start and at game exit.
-- Their :load function is never called, thus making
-- loading screen initialization is synchronous.
-- But the :resumed and :paused method are
-- called on gamestate switch.
-- Loading screen also always "strong", that
-- means the asset is never be freed, or in
-- short, it's self.data is persist as long as
-- the game is running.

-- luacheck: read_globals DEPLS_VERSION

local love = require("love")
local Gamestate = require("gamestate")
local AssetCache = require("asset_cache")
local color = require("color")
local MainFont = require("main_font")

local loading = Gamestate.create {
	-- Note that for loading screen gamestate
	-- the contents of these 2 tables are ignored,
	-- but the table itself must be exist.
	fonts = {}, images = {}
}

local loadingText = {
	"https://github.com/MikuAuahDark/livesim2",
	"Oh oh... Time Lapse Memories",
	"Oh oh... Time Lapse Starry Sky",
	"The game logic is written with Lua",
	"Powered by LÖVE framework",
	"Live Simulator: 2 version "..DEPLS_VERSION,
	"Finding rabbits...",
	"Chasing rabbits...",
	"Now comes with multiple languages",
	"MissingNo",
	"LÖVE "..love._version..": "..love._version_codename,
	"Re-designing the user interface..."
}

local function getScale(value)
	if value > 1 then
		value = 2 - value
	end
	return 0.5 - 0.5 * math.cos(math.min(math.max(value, 0), 1) * math.pi)
end

local function pickRandomText(self)
	local text = loadingText[math.random(1, #loadingText)]
	local tobj = self.data.text
	local spos = self.data.font:getWidth(text) * -0.5
	local hpos = self.data.font:getHeight() * -0.5
	tobj:clear()
	tobj:add({color.white, text}, spos, hpos)
end

function loading:start()
	local temp = {mipmaps = true}
	-- Loading screen startup is synchronous operation
	self.data.font = MainFont.get(24)
	self.data.text = love.graphics.newText(self.data.font)
	self.data.icon = {
		AssetCache.loadImage("new_icon1:assets/image/icon/new_icon_1024x1024_trim_1.png", temp),
		AssetCache.loadImage("new_icon2:assets/image/icon/new_icon_1024x1024_trim_2.png", temp),
		AssetCache.loadImage("new_icon3:assets/image/icon/new_icon_1024x1024_trim_3.png", temp)
	}
	-- peak at 0.25
	self.persist.time = {0.25, 0, 0.75, 0.5}
	self.persist.textTimer = 0

	-- Pick random text
	pickRandomText(self)
end

function loading:update(dt)
	self.persist.time[1] = (self.persist.time[1] + dt) % 1
	self.persist.time[2] = (self.persist.time[2] + dt) % 1
	self.persist.time[3] = (self.persist.time[3] + dt) % 1
	self.persist.time[4] = (self.persist.time[4] + dt) % 1

	self.persist.textTimer = self.persist.textTimer + dt * 0.5
	if self.persist.textTimer >= 1 then
		pickRandomText(self)
		self.persist.textTimer = self.persist.textTimer % 1
	end
end

function loading:draw()
	love.graphics.push()
	love.graphics.clear(color.hex6A6767)
	love.graphics.setColor(color.compat(255, 255, 255, math.sin(self.persist.textTimer * math.pi)))
	love.graphics.draw(self.data.text, 480, 586)
	love.graphics.translate(480, 320)
	love.graphics.scale(0.5)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.icon[3], 0, 0, 0, 1, 1, 464, 464)
	love.graphics.draw(self.data.icon[2], 0, 0, 0, 1, 1, 344, 344)
	love.graphics.draw(self.data.icon[1], 0, 0, 0, 1, 1, 96, 96)
	local scale = getScale(self.persist.time[1] * 4)
	if scale > 0 then
		local c, s = math.cos(math.pi * 4/10), math.sin(math.pi * 4/10)
		love.graphics.setColor(color.get(104, 227, 46, 1))
		love.graphics.circle("fill", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("fill", -440 * s, 440 * c, scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, scale * 48)
	end

	scale = getScale(self.persist.time[2] * 4)
	if scale > 0 then
		local c, s = math.cos(math.pi * 3/10), math.sin(math.pi * 3/10)
		love.graphics.setColor(color.get(255, 66, 66, 1))
		love.graphics.circle("fill", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("fill", -440 * s, 440 * c, scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, scale * 48)
	end

	scale = getScale(self.persist.time[3] * 4)
	if scale > 0 then
		local c, s = math.cos(math.pi * 2/10), math.sin(math.pi * 2/10)
		love.graphics.setColor(color.get(56, 178, 246, 1))
		love.graphics.circle("fill", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("fill", -440 * s, 440 * c, scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, scale * 48)
	end

	scale = getScale(self.persist.time[4] * 4)
	if scale > 0 then
		local c, s = math.cos(math.pi * 1/10), math.sin(math.pi * 1/10)
		love.graphics.setColor(color.get(249, 157, 49, 1))
		love.graphics.circle("fill", 440 * s, -440 * c, scale * 48)
		love.graphics.circle("line", 440 * s, -440 * c, scale * 48)
		love.graphics.setColor(color.get(230, 36, 199, 1))
		love.graphics.circle("fill", -440 * s, 440 * c, scale * 48)
		love.graphics.circle("line", -440 * s, 440 * c, scale * 48)
	end
	love.graphics.pop()
end

return loading
