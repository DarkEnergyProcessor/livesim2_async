-- Language Setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local setting = require("setting")
local mainFont = require("font")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")

local gui = require("libs.fusion-ui")
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local gameLang = gamestate.create {
	fonts = {},
	images = {},
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function updateLanguagString(text, lang)
	text:clear()
	-- FIXME (16/10/2018): https://github.com/kikito/i18n.lua/issues/28
	-- The string should be "setting.language.current", but due to issue
	-- in i18n library above, it must be renamed to "language.current".
	-- Once this fixed, we can use "setting.language.current" again.
	util.addTextWithShadow(text, L("language.current", lang), 0, 0)
end

function gameLang:load(arg)
	local curlang = setting.get("LANGUAGE")
	self.persist.languageText = love.graphics.newText(mainFont.get(26))

	if self.data.buttonFrame == nil then
		local frameElem = {}
		local frameLayout = {}
		for i, v in ipairs(L.enum()) do
			local elem = longButtonUI.new(v.name)
			elem:addEventListener("released", function()
				L.set(v.code)
				updateLanguagString(self.persist.languageText, v)
			end)
			frameElem[#frameElem + 1] = {element = elem, index = i}
			frameLayout[i] = {
				position = "absolute",
				size = "absolute",
				left = 0,
				top = (i - 1) * 78,
				w = 758,
				h = 78
			}

			if v.code == curlang then
				updateLanguagString(self.persist.languageText, v)
			end
		end

		self.data.buttonFrame = gui.element.newElement("frame", {
			elements = frameElem,
			layout = frameLayout
		}, {
			backgroundColor = {0, 0, 0, 0},
			padding = {0, #frameElem * 78, 0, 0},
			margin = {0, 0, 0, 0}
		})
	end

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(14)
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new(L"setting.language", leave)
	end
end

function gameLang:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.persist.languageText, 480, 8)

	backNavigation.draw(self.data.back)
	self.data.buttonFrame:draw(101, 50, 808, 546)
	gui.draw()
end

return gameLang
