-- Loading screen
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
-- short, it's self.data and self.assets are persist
-- as long as the game is running.

-- luacheck: read_globals DEPLS_VERSION

local love = require("love")
local gamestate = require("gamestate")
local assetCache = require("asset_cache")
local timer = require("libs.hump.timer")

local loading = gamestate.create {
	-- Note that for loading screen gamestate
	-- the contents of these 3 tables are ignored,
	-- but the table itself must be exist.
	fonts = {},
	images = {},
	audios = {}
}

local loadingText = {
	"https://github.com/MikuAuahDark/livesim2",
	"Powered with Fusion UI",
	"Oh oh... Time Lapse Memories",
	"Oh oh... Time Lapse Starry Sky",
	"The game logic is written with Lua",
	"Powered by LOVE framework",
	"Overflowing Time Lapse",
	"Refactoring code...",
	"1 FPS, 2 FPS, 2 FPS, 50 FPS",
	"\"livesim2.exe livesim time_lapse\"",
	"v"..DEPLS_VERSION,
}

function loading:start()
	self.data.mainFont = assetCache.loadFont("fonts/MTLmr3m.ttf", 24)
	self.data.icon = assetCache.loadImage("assets/image/icon/icon_128x128.png")
	self.persist.text = love.graphics.newText(self.data.mainFont)
	self.persist.rotation = 0
	self.persist.inOutCubic = timer.tween["in-out-cubic"]
end

function loading:resumed()
	local text = loadingText[math.random(1, #loadingText)]
	local tobj = self.persist.text
	local spos = self.data.mainFont:getWidth(text) * -0.5
	self.persist.rotation = 0 -- in 0..1 range
	tobj:clear()
	tobj:add({{0, 0, 0, 127}, text}, spos + -1.25, -1.25)
	tobj:add({{0, 0, 0, 127}, text}, spos + 1.25, 1.25)
	tobj:add({{255, 255, 255, 255}, text}, spos, 0)
end

function loading:update(dt)
	self.persist.rotation = self.persist.rotation + dt
	while self.persist.rotation >= 1 do
		self.persist.rotation = self.persist.rotation - 1
	end
end

function loading:draw()
	local rot = self.persist.inOutCubic(self.persist.rotation) * 2*math.pi
	love.graphics.clear(0, 187, 255, 255)
	love.graphics.draw(self.data.icon, 480, 320, rot, 1, 1, 64, 64)
	love.graphics.draw(self.persist.text, 480, 400)
end

return loading
