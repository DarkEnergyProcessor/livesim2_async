-- Main Menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER DEPLS_VERSION_CODENAME

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local MainFont = require("main_font")
local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local Util = require("util")
local L = require("language")

local BackgroundLoader = require("game.background_loader")
-- UI stuff
local Glow = require("game.afterglow")
local Ripple = require("game.ui.ripple")

-- These UIs are declared directly here because
-- they're one-specific use. It's not worth to have it in separate file
-- because they're not reusable
local PlayButton = Luaoop.class("Livesim2.MainMenu.PlayButton", Glow.Element)
local ChangeUnitsButton = Luaoop.class("Livesim2.MainMenu.ChangeUnitsButton", Glow.Element)
local SettingsButton = Luaoop.class("Livesim2.MainMenu.SettingsButton", Glow.Element)

function PlayButton:new(state)
	local text = L"menu:play"
	self.image = state.assets.images.play
	self.playText = love.graphics.newText(state.data.playFont)
	self.playText:add(text, -state.data.playFont:getWidth(text) * 0.5, 0)
	self.width, self.height = 404, 512
	self.isPressed = false
	self.x, self.y = 0, 0
	self.ripple = Ripple(math.sqrt(self.width * self.width + self.height * self.height))
	self.stencilFunc = function()
		return love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", PlayButton._pressed)
	self:addEventListener("mousereleased", PlayButton._released)
	self:addEventListener("mousecanceled", PlayButton._released)
end

function PlayButton:update(dt)
	self.ripple:update(dt)
end

function PlayButton:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function PlayButton:_released(_)
	self.isPressed = false
	self.ripple:released()
end

function PlayButton:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(color.hex55CAFD)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	Util.drawText(self.playText, x + 218, y + 212)
	love.graphics.rectangle("fill", x + 6, y, 34, self.height)
	love.graphics.rectangle("fill", x + 50, y, 34, self.height)
	love.graphics.circle("fill", x + 146, y + 114, 35)
	love.graphics.circle("fill", x + 216, y + 54, 35)
	love.graphics.circle("line", x + 146, y + 114, 35)
	love.graphics.circle("line", x + 216, y + 54, 35)
	love.graphics.setColor(color.hexFFFFFF8A)
	love.graphics.draw(self.image, x + 252, y + 364, 0, 2.2, 2.2)

	if self.ripple:isActive() then
		-- Setup stencil buffer
		Util.stencil11(self.stencilFunc, "replace", 1, false)
		Util.setStencilTest11("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		Util.setStencilTest11()
	end
end

function ChangeUnitsButton:new(state)
	local text = L"menu:changeUnits"
	self.image = state.assets.images.changeUnits
	self.text = love.graphics.newText(state.data.titleFont)
	self.text:add(text, -state.data.titleFont:getWidth(text) * 41/46, 0, 0, 41/46)
	self.width, self.height = 404, 156
	self.isPressed = false
	self.x, self.y = 0, 0
	self.ripple = Ripple(math.sqrt(self.width * self.width + self.height * self.height))
	self.stencilFunc = function()
		return love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", ChangeUnitsButton._pressed)
	self:addEventListener("mousereleased", ChangeUnitsButton._released)
	self:addEventListener("mousecanceled", ChangeUnitsButton._released)
end

function ChangeUnitsButton:update(dt)
	self.ripple:update(dt)
end

function ChangeUnitsButton:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function ChangeUnitsButton:_released(_)
	self.isPressed = false
	self.ripple:released()
end

function ChangeUnitsButton:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	Util.drawText(self.text, x + 395, y + 100)
	love.graphics.draw(self.image, x + 11, y + 22, 0, 0.32, 0.32)

	if self.ripple:isActive() then
		-- Setup stencil buffer
		Util.stencil11(self.stencilFunc, "replace", 1, false)
		Util.setStencilTest11("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		Util.setStencilTest11()
	end
end

function SettingsButton:new(state)
	local text = L"menu:settings"
	self.image = state.assets.images.settingsDualGear
	self.text = love.graphics.newText(state.data.titleFont)
	self.text:add(text, -state.data.titleFont:getWidth(text) * 41/46, 0, 0, 41/46)
	self.width, self.height = 404, 156
	self.isPressed = false
	self.x, self.y = 0, 0
	self.ripple = Ripple(math.sqrt(self.width * self.width + self.height * self.height))
	self.stencilFunc = function()
		return love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", SettingsButton._pressed)
	self:addEventListener("mousereleased", SettingsButton._released)
	self:addEventListener("mousecanceled", SettingsButton._released)
end

function SettingsButton:update(dt)
	self.ripple:update(dt)
end

function SettingsButton:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function SettingsButton:_released(_)
	self.isPressed = false
	self.ripple:released()
end

function SettingsButton:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(color.hexFF6854)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	Util.drawText(self.text, x + 395, y + 100)
	love.graphics.draw(self.image, x + 5, y + 56, 0, 0.32, 0.32)

	if self.ripple:isActive() then
		-- Setup stencil buffer
		Util.stencil11(self.stencilFunc, "replace", 1, false)
		Util.setStencilTest11("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		Util.setStencilTest11()
	end
end

-- End UI stuff

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

local mipmaps = {mipmaps = true}
local mainMenu = Gamestate.create {
	fonts = {},
	images = {
		play = {"assets/image/ui/over_the_rainbow/play.png", mipmaps},
		settingsDualGear = {"assets/image/ui/over_the_rainbow/settings_main_menu.png", mipmaps},
		changeUnits = {"assets/image/ui/over_the_rainbow/people_outline_24px_outlined.png", mipmaps}
	},
}

function mainMenu:load()
	Glow.clear()

	if not(self.data.playFont) then
		self.data.playFont = MainFont.get(92)
	end

	if not(self.data.titleFont) then
		self.data.titleFont = MainFont.get(46)
	end

	if not(self.data.titleText) then
		self.data.titleText = love.graphics.newText(self.data.titleFont, {
			color.hexFFA73D, "Live ",
			color.white, "Simulator: ",
			color.hexFF4FAE, "2"
		})
	end

	if not(self.data.verSemFont) then
		self.data.verSemFont = love.graphics.newFont(MainFont.notoSansCJK, 23)
	end

	if not(self.data.verSemText) then
		local text = love.graphics.newText(self.data.verSemFont)
		local ver = "v"..DEPLS_VERSION
		text:add(ver, -self.data.verSemFont:getWidth(ver), 0)
		self.data.verSemText = text
	end

	if not(self.data.verCodeText) then
		local text = love.graphics.newText(self.data.verSemFont)
		text:add(
			DEPLS_VERSION_CODENAME,
			-self.data.verSemFont:getWidth(DEPLS_VERSION_CODENAME) * 16/23,
			0, 0, 16/23
		)
		self.data.verCodeText = text
	end

	if not(self.data.playButton) then
		self.data.playButton = PlayButton(self)
		self.data.playButton:addEventListener("mousereleased", makeEnterGamestateFunction("beatmapSelect"))
	end
	Glow.addElement(self.data.playButton, 46, 28)

	if not(self.data.changeUnitsButton) then
		self.data.changeUnitsButton = ChangeUnitsButton(self)
		self.data.changeUnitsButton:addEventListener("mousereleased", makeEnterGamestateFunction("changeUnits"))
	end
	Glow.addElement(self.data.changeUnitsButton, 497, 29)

	if not(self.data.settingsButton) then
		self.data.settingsButton = SettingsButton(self)
		self.data.settingsButton:addEventListener("mousereleased", makeEnterGamestateFunction("settings"))
	end
	Glow.addElement(self.data.settingsButton, 497, 207)

	if not(self.data.background) then
		self.data.background = BackgroundLoader.load(2)
	end

	if not(self.data.grayGradient) then
		self.data.grayGradient = Util.gradient("vertical", color.transparent, color.hex6A6767F0)
	end
end

-- Title text "{ffa73d}Live {ffffff}Simulator: {ff4fae}2" is in 38x584 (text "title")
-- Version semantic is in 921x578 (text "versionSem")
-- Version codename is in 923x604 (text "verionCodename")

function mainMenu:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.grayGradient, -90, 576, 0, 1140, 64, 0, 0)
	Util.drawText(self.data.titleText, 38, 584)
	Util.drawText(self.data.verSemText, 921, 578)
	Util.drawText(self.data.verCodeText, 923, 604)
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
