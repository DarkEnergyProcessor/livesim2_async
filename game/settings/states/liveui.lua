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
local liveUI = require("game.live.ui")

local gui = require("libs.fusion-ui")
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local liveUISetting = gamestate.create {
	fonts = {},
	images = {},
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

-- just a copypasta from gamelang.lua
local function updateString(text, value)
	text:clear()
	util.addTextWithShadow(text, L("setting:liveUI:current", {name = value}), 0, 0)
end

function liveUISetting:load()
	local curui = setting.get("PLAY_UI")
	self.persist.text = love.graphics.newText(mainFont.get(26))

	if self.data.buttonFrame == nil then
		local frameElem = {}
		local frameLayout = {}
		for i, v in ipairs(liveUI.enum()) do
			local elem = longButtonUI.new(v)
			elem:addEventListener("released", function()
				setting.set("PLAY_UI", v)
				updateString(self.persist.text, v)
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

			if v == curui then
				updateString(self.persist.text, v)
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
		self.data.background = backgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new(L"setting:liveUI:short", leave)
	end
end

function liveUISetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.persist.text, 480, 8)

	backNavigation.draw(self.data.back)
	self.data.buttonFrame:draw(101, 50, 808, 546)
	gui.draw()
end

liveUISetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return liveUISetting
