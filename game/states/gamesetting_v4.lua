-- Game settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local async = require("async")
local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local mainFont = require("font")
local util = require("util")
local volume = require("volume")
local setting = require("setting")
local L = require("language")

local backgroundLoader = require("game.background_loader")
local tapSound = require("game.tap_sound")

local glow = require("game.afterglow")
local ciButton = require("game.ui.circle_icon_button")
local ripple = require("game.ui.ripple")

local numberSetting = require("game.settings.number_v4")
local switchSetting = require("game.settings.switch_v4")

local mipmap = {mipmaps = true}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function setVolumeSetting(name, value)
	return volume.set(name, value * 0.01)
end

local function changeBackgroundAsync(self, v)
	self.persist.background = backgroundLoader.load(v)
end

local function startChangeBackground(self, v)
	return async.runFunction(changeBackgroundAsync):run(self, v)
end

local function setBackgroundDim(self, v)
	self.persist.backgroundDim = v / 100
end

local categorySelect = Luaoop.class("Livesim2.Settings.CategorySelectUI", glow.element)

function categorySelect:new(font, name)
	self.width, self.height = 240, 48
	self.x, self.y = 0, 0
	self.active = false
	self.ripple = ripple(242.12393520674489483506979278946)
	self.isPressed = false
	self.textHeight = font:getHeight()
	self.text = love.graphics.newText(font)
	self.text:add(name, 8, (self.height - font:getHeight()) * 0.5)
	self.stencilFunc = function()
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", categorySelect._pressed)
	self:addEventListener("mousereleased", categorySelect._released)
	self:addEventListener("mousecanceled", categorySelect._released)
end

function categorySelect:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function categorySelect:_released()
	self.isPressed = false
	self.ripple:released()
end

function categorySelect:setActive(active)
	self.active = active
end

function categorySelect:update(dt)
	self.ripple:update(dt)
end

function categorySelect:render(x, y)
	self.x, self.y = x, y
	if self.active then
		love.graphics.setColor(color.hexFF4FAE)
		love.graphics.rectangle("fill", x, y, self.width, self.height)
	end
	love.graphics.setColor(self.active and color.white or color.black)
	util.drawText(self.text, x, y)

	if self.ripple:isActive() then
		love.graphics.stencil(self.stencilFunc, "replace", 1, false)
		love.graphics.setStencilTest("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
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

	if self.persist.background == nil then
		self.persist.background = backgroundLoader.load(tonumber(setting.get("BACKGROUND_IMAGE")))
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

	-- General settings
	if self.persist.generalSetting == nil then
		local frame = glow.frame(246, 86, 714, 548)
		local tapSoundDisplay = {}
		for i = 1, #tapSound do
			tapSoundDisplay[i] = tapSound[i].name
		end
		self.persist.generalFrame = frame
		self.persist.generalSetting = {
			numberSetting(frame, L"setting:general:defaultNote", "LLP_SIFT_DEFATTR", {
				min = 1, max = 11,
				display = {
					"Smile", "Pure", "Cool",
					"Blue", "Yellow", "Orange",
					"Pink", "Purple", "Gray",
					"Rainbow", "Black"
				}
			})
				:setPosition(0, 64), -- next: y+=64
			switchSetting(frame, L"setting:general:nsAccumulation", "NS_ACCUMULATION")
				:setPosition(0, 128),
			numberSetting(frame, L"setting:general:timingOffset", "TIMING_OFFSET", {
				min = -50, max = 50, default = 0
			})
				:setPosition(0, 192),
			numberSetting(frame, L"setting:general:beatmapOffset", "GLOBAL_OFFSET", {
				min = -5000, max = 5000, default = 0
			})
				:setPosition(0, 256),
			numberSetting(frame, L"setting:general:tapSound", "TAP_SOUND", {
				min = 1, max = #tapSound, default = 1, display = tapSoundDisplay
			})
				:setPosition(0, 320),
			switchSetting(frame, L"setting:general:improvedSync", "IMPROVED_SYNC")
				:setPosition(0, 384)
		}
	end
	glow.addFrame(self.persist.generalFrame)

	-- Volume settings
	if self.persist.volumeSetting == nil then
		local frame = glow.frame(246, 86, 714, 548)
		self.persist.volumeFrame = frame
		self.persist.volumeSetting = {
			numberSetting(frame, L"setting:volume:master", "MASTER_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 64)
				:setChangedCallback("master", setVolumeSetting),
			numberSetting(frame, L"setting:volume:song", "SONG_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 128)
				:setChangedCallback("music", setVolumeSetting),
			numberSetting(frame, L"setting:volume:effect", "SE_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 192)
				:setChangedCallback("se", setVolumeSetting),
			numberSetting(frame, L"setting:volume:voice", "VOICE_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 256)
				:setChangedCallback("voice", setVolumeSetting),
		}
	end

	-- Background settings
	if self.persist.bgSetting == nil then
		local frame = glow.frame(246, 86, 714, 548)
		self.persist.bgFrame = frame
		self.persist.bgSetting = {
			switchSetting(frame, L"setting:background:loadCustom", "AUTO_BACKGROUND")
				:setPosition(0, 64),
			numberSetting(frame, L"setting:background:image", "BACKGROUND_IMAGE", {min = 1, max = 15})
				:setChangedCallback(self, startChangeBackground)
				:setPosition(0, 128),
			numberSetting(frame, L"setting:background:dim", "LIVESIM_DIM", {min = 0, max = 100})
				:setChangedCallback(self, setBackgroundDim)
				:setPosition(0, 192)
		}
	end

	-- Setting selection cateogry
	if self.persist.categoryFrame == nil then
		local font = mainFont.get(22)
		self.persist.categoryFrame = glow.frame(0, 86, 240, 548)
		self.persist.settings = {
			{L"setting:general", self.persist.generalFrame, self.persist.generalSetting, nil},
			{L"setting:volume", self.persist.volumeFrame, self.persist.volumeSetting, nil},
			{L"setting:background", self.persist.bgFrame, self.persist.bgSetting, nil}
		}

		local function setSelected(_, value)
			for i, v in ipairs(self.persist.settings) do
				if i == value then
					v[4]:setActive(true)
					glow.addFrame(v[2])
				else
					v[4]:setActive(false)
					glow.removeFrame(v[2])
				end
			end

			self.persist.selectedSetting = value
		end

		for i, v in ipairs(self.persist.settings) do
			local elem = categorySelect(font, v[1])
			elem:addEventListener("mousereleased", setSelected)
			elem:setData(i)
			self.persist.categoryFrame:addElement(elem, 0, (i - 1) * 48)
			v[4] = elem
		end
	end
	glow.addFrame(self.persist.categoryFrame)
end

function gameSetting:start()
	self.persist.selectedSetting = 0
	self.persist.backgroundDim = setting.get("LIVESIM_DIM") / 100
end

function gameSetting:update(dt)
	self.persist.categoryFrame:update(dt)

	local set = self.persist.settings[self.persist.selectedSetting]
	if set then
		set[2]:update(dt)
		for _, v in ipairs(set[3]) do v:update(dt) end
	end
end

function gameSetting:draw()
	local set = self.persist.settings[self.persist.selectedSetting]

	love.graphics.setColor(color.white)
	love.graphics.draw(self.persist.background)

	-- Background setting specific
	if self.persist.selectedSetting == 3 then
		love.graphics.setColor(color.compat(0, 0, 0, self.persist.backgroundDim))
		love.graphics.rectangle("fill", -88, -43, 1136, 726)
		love.graphics.setColor(color.white25PT)
		love.graphics.rectangle("fill", 0, 0, 240, 640)

		for i = 1, #set[3] do
			love.graphics.rectangle("fill", 246, i * 64 - 12 + 86, 710, 60, 16, 16)
			love.graphics.rectangle("line", 246, i * 64 - 12 + 86, 710, 60, 16, 16)
		end
	else
		love.graphics.setColor(color.white)
		love.graphics.rectangle("fill", 0, 0, 240, 640)

		if set then
			love.graphics.setColor(color.white50PT)
			for i = 1, #set[3] do
				love.graphics.rectangle("fill", 246, i * 64 - 12 + 86, 710, 60, 16, 16)
				love.graphics.rectangle("line", 246, i * 64 - 12 + 86, 710, 60, 16, 16)
			end
		end
	end

	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(color.white)
	util.drawText(self.data.titleText, 480, 24)

	glow.draw()
	self.persist.categoryFrame:draw()

	local set = self.persist.settings[self.persist.selectedSetting]
	if set then
		set[2]:draw()
		for _, v in ipairs(set[3]) do v:draw() end
	end
end

gameSetting:registerEvent("keyreleased", function(_, k)
	if k == "escape" then
		return leave()
	end
end)

return gameSetting
