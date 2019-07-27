-- Game settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local mainFont = require("font")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local ciButton = require("game.ui.circle_icon_button")

local numberSetting = require("game.settings.number_v4")

local mipmap = {mipmaps = true}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function insertSetting(self, frame, kind, x, data)
	if kind == "number" then
	else
		error("unknown kind "..kind)
	end
end

-- Setting section frame size is 868x426+50+184
-- Tab selection is 868x62+50+162
local gameSetting = gamestate.create {
	images = {
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmap},
	},
	fonts = {}
}

function gameSetting:load()
	glow.clear()
	self.data = self.data or {} -- for sake of LCA

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(2)
	end

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = util.gradient("vertical", color.black75PT, color.transparent)
	end

	if self.data.titleText == nil then
		local f = mainFont.get(31)
		local t = love.graphics.newText(f)
		local l = L"menu:settings"
		t:add(l, -0.5 * f:getWidth(l), 0)
		self.data.titleText = t
	end

	if self.data.back == nil then
		self.data.back = ciButton(color.hexFF4FAE, 36, self.assets.images.navigateBack, 0.48)
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 32, 4)
end

function gameSetting:start()
	self.persist = self.persist or {} -- for sake of LCA

	-- Categories
	self.persist.categoryFrame = glow.frame(0, 86, 240, 554)

	-- General settings
	local generalFrame = glow.frame(246, 86, 714, 548)
	self.persist.generalSetting = {
		numberSetting(generalFrame, L"setting:general:defaultNote", "LLP_SIFT_DEFATTR", {
			min = 1, max = 11,
			display = {
				"Smile", "Pure", "Cool",
				"Blue", "Yellow", "Orange",
				"Pink", "Purple", "Gray",
				"Rainbow", "Black"
			}
		})
			:setPosition(0, 64), -- next: y+=64
		switchSetting(generalFrame, L"setting:general:nsAccumulation", "NS_ACCUMULATION")
			:setPosition(0, 128),
		numberSetting(generalFrame, L"setting:general:timingOffset", "TIMING_OFFSET", {
			min = -50, max = 50, default = 0
		})
			:setPosition(0, 192),
		numberSetting(generalFrame, L"setting:general:beatmapOffset", "GLOBAL_OFFSET", {
			min = -5000, max = 5000, default = 0
		})
			:setPosition(0, 256),
		numberSetting(generalFrame, L"setting:general:tapSound", "TAP_SOUND", {
			min = 1, max = #tapSound, default = 1
		})
			:setPosition(0, 320),
		switchSetting(generalFrame, L"setting:general:improvedSync", "IMPROVED_SYNC")
			:setPosition(0, 384)
	}
end

function gameSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(color.white)
	util.drawText(self.data.titleText, 480, 24)

	glow.draw()
end

gameSetting:registerEvent("keyreleased", function(_, k)
	if k == "escape" then
		return leave()
	end
end)

return gameSetting
