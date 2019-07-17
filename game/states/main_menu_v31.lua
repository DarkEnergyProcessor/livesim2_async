-- Main Menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER DEPLS_VERSION_CODENAME

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local mainFont = require("font")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")
-- UI stuff
local glow = require("game.afterglow")
local ripple = require("game.ui.ripple")

-- These UIs are declared directly here because
-- they're one-specific use. It's not worth to have it in separate file
-- because they're not reusable
local invisibleButton = Luaoop.class("Livesim2.InvisibleButtonUI", glow.element)
local playButton = Luaoop.class("Livesim2.MainMenu.PlayButton", glow.element)
local changeUnitsButton = Luaoop.class("Livesim2.MainMenu.ChangeUnitsButton", glow.element)
local settingsButton = Luaoop.class("Livesim2.MainMenu.SettingsButton", glow.element)

function playButton:new(state)
	local text = L"menu:play"
	self.image = state.assets.images.play
	self.playText = love.graphics.newText(state.data.playFont)
	self.playText:add(text, -state.data.playFont:getWidth(text) * 0.5, 0)
	self.width, self.height = 404, 512
	self.isPressed = false
	self.x, self.y = 0, 0
	self.ripple = ripple(math.sqrt(self.width * self.width + self.height * self.height))
	self.stencilFunc = function()
		return love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", playButton._pressed)
	self:addEventListener("mousereleased", playButton._released)
	self:addEventListener("mousecanceled", playButton._released)
end

function playButton:update(dt)
	self.ripple:update(dt)
end

function playButton:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function playButton:_released(_)
	self.isPressed = false
	self.ripple:released()
end

function playButton:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(color.hex55CAFD)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	util.drawText(self.playText, x + 218, y + 212)
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
		love.graphics.stencil(self.stencilFunc, "replace", 1, false)
		love.graphics.setStencilTest("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
	end
end

function changeUnitsButton:new(state)
	local text = L"menu:changeUnits"
	self.image = state.assets.images.changeUnits
	self.text = love.graphics.newText(state.assets.fonts.title)
	self.text:add(text, -state.assets.fonts.title:getWidth(text) * 41/46, 0, 0, 41/46)
	self.width, self.height = 404, 156
	self.isPressed = false
	self.x, self.y = 0, 0
	self.ripple = ripple(math.sqrt(self.width * self.width + self.height * self.height))
	self.stencilFunc = function()
		return love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", changeUnitsButton._pressed)
	self:addEventListener("mousereleased", changeUnitsButton._released)
	self:addEventListener("mousecanceled", changeUnitsButton._released)
end

function changeUnitsButton:update(dt)
	self.ripple:update(dt)
end

function changeUnitsButton:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function changeUnitsButton:_released(_)
	self.isPressed = false
	self.ripple:released()
end

function changeUnitsButton:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	util.drawText(self.text, x + 395, y + 100)
	love.graphics.draw(self.image, x + 11, y + 22, 0, 0.32, 0.32)

	if self.ripple:isActive() then
		-- Setup stencil buffer
		love.graphics.stencil(self.stencilFunc, "replace", 1, false)
		love.graphics.setStencilTest("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
	end
end

function settingsButton:new(state)
	local text = L"menu:settings"
	self.image = state.assets.images.settingsDualGear
	self.text = love.graphics.newText(state.assets.fonts.title)
	self.text:add(text, -state.assets.fonts.title:getWidth(text) * 41/46, 0, 0, 41/46)
	self.width, self.height = 404, 156
	self.isPressed = false
	self.x, self.y = 0, 0
	self.ripple = ripple(math.sqrt(self.width * self.width + self.height * self.height))
	self.stencilFunc = function()
		return love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", settingsButton._pressed)
	self:addEventListener("mousereleased", settingsButton._released)
	self:addEventListener("mousecanceled", settingsButton._released)
end

function settingsButton:update(dt)
	self.ripple:update(dt)
end

function settingsButton:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function settingsButton:_released(_)
	self.isPressed = false
	self.ripple:released()
end

function settingsButton:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(color.hexFF6854)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	util.drawText(self.text, x + 395, y + 100)
	love.graphics.draw(self.image, x + 5, y + 56, 0, 0.32, 0.32)

	if self.ripple:isActive() then
		-- Setup stencil buffer
		love.graphics.stencil(self.stencilFunc, "replace", 1, false)
		love.graphics.setStencilTest("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
	end
end

function invisibleButton:new(w, h)
	self.width, self.height = w, h
end

function invisibleButton.render() end

-- End UI stuff

local function makeEnterGamestateFunction(name, noloading)
	if noloading then
		return function()
			return gamestate.enter(nil, name)
		end
	else
		return function()
			return gamestate.enter(loadingInstance.getInstance(), name)
		end
	end
end

local mipmaps = {mipmaps = true}
local mainMenu = gamestate.create {
	fonts = {
		title = {"fonts/Roboto-Regular.ttf", 46},
		versionSem = {"fonts/NotoSansCJKjp-Regular.woff", 23}
	},
	images = {
		play = {"assets/image/ui/over_the_rainbow/play.png", mipmaps},
		settingsDualGear = {"assets/image/ui/over_the_rainbow/settings_main_menu.png", mipmaps},
		changeUnits = {"assets/image/ui/over_the_rainbow/people_outline_24px_outlined.png", mipmaps}
	},
}

function mainMenu:load()
	glow.clear()

	if not(self.data.playFont) then
		self.data.playFont = mainFont.get(92)
	end

	if not(self.data.titleText) then
		self.data.titleText = love.graphics.newText(self.assets.fonts.title, {
			color.hexFFA73D, "Live ",
			color.white, "Simulator: ",
			color.hexFF4FAE, "2"
		})
	end

	if not(self.data.verSemText) then
		local text = love.graphics.newText(self.assets.fonts.versionSem)
		local ver = "v"..DEPLS_VERSION
		text:add(ver, -self.assets.fonts.versionSem:getWidth(ver), 0)
		self.data.verSemText = text
	end

	if not(self.data.verCodeText) then
		local text = love.graphics.newText(self.assets.fonts.versionSem)
		text:add(
			DEPLS_VERSION_CODENAME,
			-self.assets.fonts.versionSem:getWidth(DEPLS_VERSION_CODENAME) * 16/23,
			0, 0, 16/23
		)
		self.data.verCodeText = text
	end

	if not(self.data.playButton) then
		self.data.playButton = playButton(self)
		self.data.playButton:addEventListener("mousereleased", makeEnterGamestateFunction("beatmapSelect"))
	end
	glow.addElement(self.data.playButton, 46, 28)

	if not(self.data.changeUnitsButton) then
		self.data.changeUnitsButton = changeUnitsButton(self)
		self.data.changeUnitsButton:addEventListener("mousereleased", makeEnterGamestateFunction("changeUnits"))
	end
	glow.addElement(self.data.changeUnitsButton, 497, 29)

	if not(self.data.settingsButton) then
		local a = makeEnterGamestateFunction("settings")
		local b = makeEnterGamestateFunction("settings\0")
		self.data.settingsButton = settingsButton(self)
		self.data.settingsButton:addEventListener("mousereleased", function()
			return (love.keyboard.isDown("lshift", "rshift") and b or a)()
		end)
	end
	glow.addElement(self.data.settingsButton, 497, 207)

	if not(self.data.background) then
		self.data.background = backgroundLoader.load(2)
	end

	if not(self.data.grayGradient) then
		self.data.grayGradient = util.gradient("vertical", color.transparent, color.hex6A6767F0)
	end

	local invbtn = invisibleButton(240, 80)
	invbtn:addEventListener("mousereleased", makeEnterGamestateFunction("systemInfo", true))
	glow.addFixedElement(invbtn, 720, 560)
end

-- Title text "{ffa73d}Live {ffffff}Simulator: {ff4fae}2" is in 38x584 (text "title")
-- Version semantic is in 921x578 (text "versionSem")
-- Version codename is in 923x604 (text "verionCodename")

function mainMenu:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.grayGradient, -90, 576, 0, 1140, 64, 0, 0)
	util.drawText(self.data.titleText, 38, 584)
	util.drawText(self.data.verSemText, 921, 578)
	util.drawText(self.data.verCodeText, 923, 604)
	return glow.draw()
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
