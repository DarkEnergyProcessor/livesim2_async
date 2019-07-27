-- Number setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local setting = require("setting")
local color = require("color")
local mainFont = require("font")
local util = require("util")
local assetCache = require("asset_cache")

local ciButton = require("game.ui.circle_icon_button")

local baseSetting = require("game.settings.base_v4")
local numberSetting = Luaoop.class("Livesim2.SettingItem.Number", baseSetting)

local function snapAt(v, snap)
	return math.floor(v/snap) * snap
end

local function makePressed(obj, dir)
	return function()
		local internal = Luaoop.class.data(obj)
		local value = util.clamp(internal.value + internal.snap * dir, internal.range.min, internal.range.max)
		if value ~= internal.value then
			internal.value = snapAt(value, internal.snap)
			internal.holdDelay = 0
			internal.updateDirection = dir
			obj:_updateValueDisplay()
			obj:_emitChangedCallback(internal.value)
		end
	end
end

local INCREASE_X, INCREASE_Y = 420 + 160, 0
local DECREASE_X, DECREASE_Y = 420 - 36, 0
local RELOAD_X, RELOAD_Y = 420 + 160 + 40, 0

function numberSetting:__construct(frame, name, settingName, opts)
	local internal = Luaoop.class.data(self)
	baseSetting.__construct(self, name)

	local img = assetCache.loadImage("assets/image/ui/over_the_rainbow/navigate_back.png", {mipmaps = true})
	internal.holdDelay = -math.huge
	internal.updateDirection = 0
	internal.range = opts
	internal.value = util.clamp(opts.value or setting.get(settingName), opts.min, opts.max)
	internal.font = mainFont.get(22)
	internal.valueDisplay = love.graphics.newText(internal.font)
	internal.snap = opts.snap or 1
	internal.frame = frame
	internal.display = opts.display or {}

	local function released()
		internal.holdDelay = -math.huge
		internal.updateDirection = 0
		if settingName then setting.set(settingName, internal.value) end
	end

	internal.increaseButton = ciButton(color.transparent, 18, img, 0.24, color.hexFF4FAE, math.pi)
	internal.increaseButton:addEventListener("mousepressed", makePressed(self, 1))
	internal.increaseButton:addEventListener("mousereleased", released)
	frame:addElement(internal.increaseButton, self.x + INCREASE_X, self.y + INCREASE_Y)
	internal.decreaseButton = ciButton(color.transparent, 18, img, 0.24, color.hexFF4FAE)
	internal.decreaseButton:addEventListener("mousepressed", makePressed(self, -1))
	internal.decreaseButton:addEventListener("mousereleased", released)
	frame:addElement(internal.decreaseButton, self.x + DECREASE_X, self.y + DECREASE_Y)
	if opts.default then
		local reload = assetCache.loadImage("assets/image/ui/over_the_rainbow/reload.png", {mipmaps = true})
		internal.resetButton = ciButton(color.transparent, 18, reload, 0.32, color.hexFF4FAE)
		internal.resetButton:addEventListener("mousereleased", function()
			if internal.value ~= opts.default then
				internal.value = opts.default
				if settingName then setting.set(settingName, opts.default) end
				self:_updateValueDisplay()
				self:_emitChangedCallback(opts.default)
			end
		end)
		frame:addElement(internal.resetButton, self.x + RELOAD_X, self.y + RELOAD_Y)
	end

	return self:_updateValueDisplay()
end

function numberSetting:__destruct()
	local internal = Luaoop.class.data(self)

	internal.frame:removeElement(internal.increaseButton)
	internal.frame:removeElement(internal.decreaseButton)
	if internal.resetButton then
		internal.frame:removeElement(internal.resetButton)
	end
end

function numberSetting:_updateValueDisplay()
	local internal = Luaoop.class.data(self)

	local s = tostring(internal.display[internal.value] or internal.value)
	local w = internal.font:getWidth(s) * 0.5
	internal.valueDisplay:clear()
	internal.valueDisplay:add({color.white, s}, 0, 0, 0, 1, 1, w, 0)
end

function numberSetting:_positionChanged()
	local internal = Luaoop.class.data(self)

	internal.frame:setElementPosition(internal.increaseButton, self.x + INCREASE_X, self.y)
	internal.frame:setElementPosition(internal.decreaseButton, self.x + DECREASE_X, self.y)
	if internal.resetButton then
		internal.frame:setElementPosition(internal.resetButton, self.x + RELOAD_X, self.y)
	end
end

function numberSetting:update(dt)
	local internal = Luaoop.class.data(self)

	internal.holdDelay = internal.holdDelay + dt * 2
	if internal.holdDelay >= 1 then
		local value = util.clamp(
			internal.value + internal.snap * math.floor(internal.holdDelay) * internal.updateDirection,
			internal.range.min,
			internal.range.max
		)
		if value ~= internal.value then
			internal.value = snapAt(value, internal.snap)
			self:_updateValueDisplay()
			self:_emitChangedCallback(internal.value)
		end
	end
end

function numberSetting:getValue()
	local internal = Luaoop.class.data(self)
	return internal.value
end

function numberSetting:setValue(v)
	local internal = Luaoop.class.data(self)

	assert(type(v) == "number", "invalid value")
	v = util.clamp(v, internal.range.min, internal.range.max)
	if v ~= internal.value then
		internal.value = snapAt(v, internal.snap)
		self:_updateValueDisplay()
		self:_emitChangedCallback(internal.value)
	end
end

function numberSetting:draw()
	local internal = Luaoop.class.data(self)
	baseSetting.draw(self)
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("line", self.x + 420 + 246, self.y + 86, 160, 36, 18, 18)
	love.graphics.draw(internal.valueDisplay, self.x + 500 + 246, self.y + 5 + 86)
end

return numberSetting
