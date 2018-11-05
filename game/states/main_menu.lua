-- Main Menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua
-- luacheck: read_globals DEPLS_VERSION DEPLS_VERSION_NUMBER

local love = require("love")
local color = require("color")
local L = require("language")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local backgroundLoader = require("game.background_loader")

local gui = require("libs.fusion-ui")
local glow = require("game.afterglow")
local menuButtonUI = require("game.ui.menu_button")
local imageButtonUI = require("game.ui.image_button")

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
	blist.play = menuButtonUI(L"menu:play")
	blist.play:addEventListener("mousereleased", makeEnterGamestateFunction("beatmapSelect"))
	-- Change units button
	blist.changeUnits = menuButtonUI(L"menu:changeUnits")
	blist.changeUnits:addEventListener("mousereleased", makeEnterGamestateFunction("changeUnits"))
	-- Settings button
	blist.settings = menuButtonUI(L"menu:settings")
	blist.settings:addEventListener("mousereleased", makeEnterGamestateFunction("settings"))
	-- Exit button
	blist.exit = menuButtonUI(L"menu:quit")
	blist.exit:addEventListener("mousereleased", function()
		if love._os ~= "iOS" then
			gamestate.leave()
		end
	end)

	blist.language = imageButtonUI("assets/image/ui/lang")
	blist.language:addEventListener("mousereleased", makeEnterGamestateFunction("language"))

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

	if jit and jit.status() then
		bld[#bld + 1] = "JIT "
	end

	local renderInfo = {love.graphics.getRendererInfo()}
	bld[#bld + 1] = "\n"..L("menu:renderer")..": "
	bld[#bld + 1] = renderInfo[1]

	for i = 2, 4 do
		if renderInfo[i] then
			bld[#bld + 1] = " "
			bld[#bld + 1] = renderInfo[i]
		end
	end

	bld[#bld + 1] = "\n"..L("menu:writeDir")..": "
	bld[#bld + 1] = love.filesystem.getSaveDirectory()
	bld = table.concat(bld)

	local text = love.graphics.newText(self.assets.fonts.main)
	text:add({color.black, bld}, 1.25, 1.25)
	text:add({color.white, bld}, 0, 0)

	return text
end

function mainMenu:load()
	glow.clear()

	-- Load buttons
	if self.data.buttons == nil then
		self.data.buttons = initializeButtons()
	end
	glow.addElement(self.data.buttons.play, 16, 120+80*1)
	glow.addElement(self.data.buttons.changeUnits, 16, 120+80*2)
	glow.addElement(self.data.buttons.settings, 16, 120+80*3)
	glow.addElement(self.data.buttons.exit, 16, 120+80*4)
	glow.addElement(self.data.buttons.language, 914, 592)

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
	-- Draw UI
	glow.draw()
end

return mainMenu
