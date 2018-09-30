-- Main Menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua
-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER

local love = require("love")
local color = require("color")
local timer = require("libs.hump.timer")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local backgroundLoader = require("game.background_loader")

local gui = require("libs.fusion-ui")
local menuButtonUI = require("game.ui.menu_button")

local mainMenu = gamestate.create {
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 16},
		title = {"fonts/MTLmr3m.ttf", 72},
	},
	images = {
		icon = {"assets/image/icon/icon_128x128.png"}
	},
}

local function makeEnterGamestateFunction(name)
	return function()
		return gamestate.enter(loadingInstance.getInstance(), name)
	end
end

local function initializeButtons()
	local blist = {}
	-- Play button
	blist.play = menuButtonUI.new("Play")
	blist.play:addEventListener("released", makeEnterGamestateFunction("beatmapSelect"))
	-- Change units button
	blist.changeUnits = menuButtonUI.new("Change Units")
	blist.changeUnits:addEventListener("released", makeEnterGamestateFunction("changeUnits"))
	-- Settings button
	blist.settings = menuButtonUI.new("Settings")
	blist.settings:addEventListener("released", makeEnterGamestateFunction("settings"))
	-- Exit button
	blist.exit = menuButtonUI.new("Exit")
	blist.exit:addEventListener("released", function()
		if love._os ~= "iOS" then
			gamestate.leave()
		end
	end)
	return blist
end

local function initializeVersionText(self)
	local bld = {}

	bld[#bld + 1] = "Live Simulator: 2 v"
	bld[#bld + 1] = DEPLS_VERSION
	bld[#bld + 1] = " ("
	bld[#bld + 1] = string.format("%08d", DEPLS_VERSION_NUMBER)
	bld[#bld + 1] = ") ("
	bld[#bld + 1] = jit and jit.version or _VERSION
	bld[#bld + 1] = ") "

	if os.getenv("LLA_IS_SET") then
		-- From modified Openal-Soft
		bld[#bld + 1] = "LLA:"
		bld[#bld + 1] = os.getenv("LLA_BUFSIZE")
		bld[#bld + 1] = "smp/"
		bld[#bld + 1] = os.getenv("LLA_FREQUENCY")
		bld[#bld + 1] = "Hz "
	end

	if jit.status() then
		bld[#bld + 1] = "JIT "
	end

	local renderInfo = {love.graphics.getRendererInfo()}
	bld[#bld + 1] = "\nRenderer: "
	bld[#bld + 1] = renderInfo[1]

	for i = 2, 4 do
		if renderInfo[i] then
			bld[#bld + 1] = " "
			bld[#bld + 1] = renderInfo[i]
		end
	end

	bld[#bld + 1] = "\nR/W Directory: "
	bld[#bld + 1] = love.filesystem.getSaveDirectory()
	bld = table.concat(bld)

	local text = love.graphics.newText(self.assets.fonts.main)
	text:add({color.black, bld}, 1.25, 1.25)
	text:add({color.white, bld}, 0, 0)

	return text
end

function mainMenu:load()
	-- Load buttons
	if self.data.buttons == nil then
		self.data.buttons = initializeButtons()
	end
	-- Load background
	if self.data.background == nil then
		self.data.background = backgroundLoader.load(14)
	end
	-- Load version text
	if self.data.text == nil then
		self.data.text = initializeVersionText(self)
	end
	-- Load title text
	if self.data.titleText == nil then
		local text = love.graphics.newText(self.assets.fonts.title)
		text:add({color.black50PT, "Live Simulator: 2"}, 2, 2)
		text:add({color.black50PT, "Live Simulator: 2"}, -2, -2)
		text:add({color.white, "Live Simulator: 2"}, 0, 0)
		self.data.titleText = text
	end
end

local function animateMainMenu(buttons)
	local target = {xoffset = 0, canvasColor = {[4] = 255}}
	buttons.play.xoffset = 60
	buttons.play.canvasColor[4] = 0
	timer.tween(0.3, buttons.play, target, "out-quad")
	buttons.changeUnits.xoffset = 60
	buttons.changeUnits.canvasColor[4] = 0
	timer.tween(0.45, buttons.changeUnits, target, "out-quad")
	buttons.settings.xoffset = 60
	buttons.settings.canvasColor[4] = 0
	timer.tween(0.6, buttons.settings, target, "out-quad")
	buttons.exit.xoffset = 60
	buttons.exit.canvasColor[4] = 0
	timer.tween(0.75, buttons.exit, target, "out-quad")
end

function mainMenu:start()
	return animateMainMenu(self.data.buttons)
end

function mainMenu:resumed()
	return animateMainMenu(self.data.buttons)
end

function mainMenu:draw()
	love.graphics.setColor(color.white)
	-- Draw background
	love.graphics.draw(self.data.background)
	-- Draw version text
	love.graphics.draw(self.data.text, 2, 592)
	-- Draw icon
	love.graphics.draw(self.assets.images.icon, 140, 46)
	-- Draw title
	love.graphics.draw(self.data.titleText, 280, 78)
	-- Draw buttons
	menuButtonUI.draw(self.data.buttons.play, 16, 120+80*1)
	menuButtonUI.draw(self.data.buttons.changeUnits, 16, 120+80*2)
	menuButtonUI.draw(self.data.buttons.settings, 16, 120+80*3)
	menuButtonUI.draw(self.data.buttons.exit, 16, 120+80*4)
	gui.draw()
end

return mainMenu
