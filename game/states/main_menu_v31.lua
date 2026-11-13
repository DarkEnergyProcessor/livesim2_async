-- Main Menu (sleek restyle for the SIF gift fork)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER DEPLS_VERSION_CODENAME

local love = require("love")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local Util = require("util")
local L = require("language")

local Glow = require("game.afterglow")
local Sleek = require("game.ui.sleek")

---------------------------------------------------------------- tile element

local Tile = Luaoop.class("Livesim2.MainMenu.SleekTile", Glow.Element)

function Tile:new(w, h, drawFunc)
	self.width, self.height = w, h
	self.drawFunc = drawFunc
	self.isPressed = false
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

function Tile:render(x, y)
	self.drawFunc(x, y, self.width, self.height, self.isPressed)
end

---------------------------------------------------------------- tiles

local PLAY_X, PLAY_Y, PLAY_W, PLAY_H = 40, 84, 420, 516
local COL_X, COL_W = 476, 444
local ROW_H, ROW_GAP = 161, 16

local function countSongs()
	local ok, items = pcall(love.filesystem.getDirectoryItems, "beatmap")
	return ok and #items or 0
end

local function drawPlay(self)
	return function(x, y, w, h, pressed)
		local r = 32
		-- soft colored shadow
		local a = Sleek.color.accent
		love.graphics.setColor(a[1], a[2], a[3], Sleek.isDark() and 0.10 or 0.14)
		love.graphics.rectangle("fill", x + 10, y + 8, w - 20, h, r, r, 32)
		Sleek.setColor(Sleek.color.accent)
		love.graphics.rectangle("fill", x, y, w, h, r, r, 32)

		-- decorative rings, clipped to the tile
		Util.stencil11(function()
			love.graphics.rectangle("fill", x, y, w, h, r, r, 32)
		end, "replace", 1, false)
		Util.setStencilTest11("equal", 1)
		love.graphics.setLineWidth(2)
		love.graphics.setColor(1, 1, 1, 0.35)
		love.graphics.circle("line", x + w - 70, y + 70, 180, 96)
		love.graphics.setColor(1, 1, 1, 0.25)
		love.graphics.circle("line", x + w - 70, y + 70, 120, 96)
		love.graphics.setLineWidth(1)
		Util.setStencilTest11()

		local subFont, playFont = Sleek.font(18), Sleek.font(72, "light")
		local subY = y + h - 36 - subFont:getHeight()
		local playY = subY - playFont:getHeight() + 4

		-- play disc
		local cx, cy = x + 36 + 48, playY - 12 - 48
		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.circle("fill", cx, cy, 48, 64)
		Sleek.iconPlay(cx + 2, cy, 40, Sleek.color.accent)

		love.graphics.setColor(1, 1, 1, 1)
		love.graphics.setFont(playFont)
		love.graphics.print(L"menu:play", x + 32, playY)
		love.graphics.setFont(subFont)
		love.graphics.setColor(1, 1, 1, 0.92)
		love.graphics.print(self.persist.songText, x + 36, subY)

		if pressed then
			love.graphics.setColor(0, 0, 0, 0.08)
			love.graphics.rectangle("fill", x, y, w, h, r, r, 32)
		end
	end
end

local function drawRow(label, soft, ink, icon)
	return function(x, y, w, h, pressed)
		Sleek.panel(x, y, w, h, 28)
		local cx, cy = x + 28 + 34, y + h / 2
		Sleek.setColor(soft)
		love.graphics.circle("fill", cx, cy, 34, 64)
		icon(cx, cy, 34, ink)
		Sleek.setColor(Sleek.color.text)
		local font = Sleek.font(30, "medium")
		love.graphics.setFont(font)
		love.graphics.print(label, x + 28 + 68 + 22, cy - font:getHeight() / 2)
		Sleek.chevron(x + w - 36, cy, "right", 8)
		if pressed then
			love.graphics.setColor(0, 0, 0, 0.05)
			love.graphics.rectangle("fill", x, y, w, h, 28, 28, 32)
		end
	end
end

-- sun (light mode) / moon (dark mode) toggle
local function drawThemeToggle(x, y, w, h, pressed)
	local cx, cy = x + w / 2, y + h / 2
	Sleek.setColor(Sleek.color.panel)
	love.graphics.circle("fill", cx, cy, w / 2, 48)
	Sleek.setColor(Sleek.color.border)
	love.graphics.circle("line", cx, cy, w / 2, 48)
	Sleek.setColor(Sleek.color.text)
	if Sleek.isDark() then
		-- crescent moon
		love.graphics.circle("fill", cx, cy, 9, 40)
		Sleek.setColor(Sleek.color.panel)
		love.graphics.circle("fill", cx + 5, cy - 4, 8, 40)
	else
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", cx, cy, 5.5, 32)
		for i = 0, 7 do
			local a = i * math.pi / 4
			love.graphics.line(cx + math.cos(a) * 9, cy + math.sin(a) * 9, cx + math.cos(a) * 12, cy + math.sin(a) * 12)
		end
		love.graphics.setLineWidth(1)
	end
	if pressed then
		love.graphics.setColor(0, 0, 0, 0.06)
		love.graphics.circle("fill", cx, cy, w / 2, 48)
	end
end

---------------------------------------------------------------- state

local function makeEnterGamestateFunction(name, noloading)
	if noloading then
		return function()
			return Gamestate.enter(nil, name)
		end
	else
		return function()
			return Gamestate.enter(LoadingInstance.getInstance(), name)
		end
	end
end

local mainMenu = Gamestate.create {
	fonts = {},
	images = {},
}

function mainMenu:load()
	Glow.clear()
	Sleek.loadTheme()

	local n = countSongs()
	self.persist.songText = n == 1 and "1 song" or string.format("%d songs", n)

	if not(self.data.playButton) then
		self.data.playButton = Tile(PLAY_W, PLAY_H, drawPlay(self))
		self.data.playButton:addEventListener("mousereleased", makeEnterGamestateFunction("beatmapSelect"))
	end
	Glow.addElement(self.data.playButton, PLAY_X, PLAY_Y)

	if not(self.data.changeUnitsButton) then
		self.data.changeUnitsButton = Tile(COL_W, ROW_H, drawRow("Team",
			Sleek.color.accentSoft, Sleek.color.accentDark, Sleek.iconPeople))
		self.data.changeUnitsButton:addEventListener("mousereleased", makeEnterGamestateFunction("teamSelect"))
	end
	Glow.addElement(self.data.changeUnitsButton, COL_X, PLAY_Y)

	if not(self.data.settingsButton) then
		self.data.settingsButton = Tile(COL_W, ROW_H, drawRow(L"menu:settings",
			Sleek.color.blueSoft, Sleek.color.blueDark, Sleek.iconGear))
		self.data.settingsButton:addEventListener("mousereleased", makeEnterGamestateFunction("settings"))
	end
	Glow.addElement(self.data.settingsButton, COL_X, PLAY_Y + ROW_H + ROW_GAP)

	if not(self.data.timingButton) then
		self.data.timingButton = Tile(COL_W, ROW_H, drawRow("Timing",
			Sleek.color.goldSoft, Sleek.color.goldDark, Sleek.iconClock))
		self.data.timingButton:addEventListener("mousereleased", makeEnterGamestateFunction("calibration"))
	end
	Glow.addElement(self.data.timingButton, COL_X, PLAY_Y + (ROW_H + ROW_GAP) * 2)

	if not(self.data.themeButton) then
		self.data.themeButton = Tile(40, 40, drawThemeToggle)
		self.data.themeButton:addEventListener("mousereleased", function() Sleek.toggleTheme() end)
	end
	Glow.addElement(self.data.themeButton, 880, 22)
end

function mainMenu:resumed()
	local n = countSongs()
	self.persist.songText = n == 1 and "1 song" or string.format("%d songs", n)
end

function mainMenu:draw()
	Sleek.background()

	-- wordmark
	Sleek.setColor(Sleek.color.accent)
	love.graphics.circle("fill", 45, 42, 5, 24)
	Sleek.setColor(Sleek.color.text)
	love.graphics.setFont(Sleek.font(20, "medium"))
	love.graphics.print("Live Simulator: 2", 60, 28)

	local verFont = Sleek.font(14)
	love.graphics.setFont(verFont)
	Sleek.setColor(Sleek.color.muted)
	local ver = "v"..tostring(DEPLS_VERSION)
	love.graphics.print(ver, 864 - verFont:getWidth(ver), 32)

	return Glow.draw()
end

mainMenu:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		local b = love.window.showMessageBox(
			L"dialog:quit:title",
			L"dialog:quit:confirm",
			{
				L"dialog:no",
				L"dialog:yes",
				enterbutton = 2,
				escapebutton = 1
			},
			"info"
		)
		if b == 2 then
			love.event.quit()
		end
	end
end)

return mainMenu
