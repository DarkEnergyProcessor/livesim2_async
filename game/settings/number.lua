-- Number setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local setting = require("setting")
local color = require("color")
local mainFont = require("font")
local util = require("util")

local Luaoop = require("libs.Luaoop")

local baseSetting = require("game.settings.base")

local glow = require("game.afterglow")
local imageButtonUI = require("game.ui.image_button")

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

function numberSetting:__construct(name, settingName, opts)
	local internal = Luaoop.class.data(self)
	baseSetting.__construct(self, name)

	internal.holdDelay = -math.huge
	internal.updateDirection = 0
	internal.range = opts
	internal.value = util.clamp(opts.value or setting.get(settingName), opts.min, opts.max)
	internal.font = mainFont.get(36)
	internal.valueDisplay = love.graphics.newText(internal.font)
	internal.snap = opts.snap or 1

	local function released()
		internal.holdDelay = -math.huge
		internal.updateDirection = 0
		if settingName then setting.set(settingName, internal.value) end
	end

	internal.increaseButton = imageButtonUI("assets/image/ui/set_button_33")
	internal.increaseButton:addEventListener("mousepressed", makePressed(self, 1))
	internal.increaseButton:addEventListener("mousereleased", released)
	glow.addElement(internal.increaseButton, self.x + 734, self.y + 16)
	internal.decreaseButton = imageButtonUI("assets/image/ui/set_button_34")
	internal.decreaseButton:addEventListener("mousepressed", makePressed(self, -1))
	internal.decreaseButton:addEventListener("mousereleased", released)
	glow.addElement(internal.decreaseButton, self.x + 556, self.y + 16)
	if opts.default then
		internal.resetButton = imageButtonUI("assets/image/ui/set_button_18")
		internal.resetButton:addEventListener("mousereleased", function()
			if internal.value ~= opts.default then
				internal.value = opts.default
				if settingName then setting.set(settingName, opts.default) end
				self:_updateValueDisplay()
				self:_emitChangedCallback(opts.default)
			end
		end)
		glow.addElement(internal.resetButton, self.x + 396, self.y + 11)
	end

	return self:_updateValueDisplay()
end

function numberSetting:__destruct()
	local internal = Luaoop.class.data(self)

	glow.removeElement(internal.increaseButton)
	glow.removeElement(internal.decreaseButton)
	if internal.resetButton then
		glow.removeElement(internal.resetButton)
	end
end

function numberSetting:_updateValueDisplay()
	local internal = Luaoop.class.data(self)

	local s = tostring(internal.value)
	local w = internal.font:getWidth(internal.value) * 0.5
	internal.valueDisplay:clear()
	internal.valueDisplay:add({color.black, s}, 0, 0, 0, 1, 1, w, 0)
end

function numberSetting:_positionChanged()
	local internal = Luaoop.class.data(self)

	glow.setElementPosition(internal.increaseButton, self.x + 734, self.y + 16)
	glow.setElementPosition(internal.decreaseButton, self.x + 556, self.y + 16)
	if internal.resetButton then
		glow.setElementPosition(internal.resetButton, self.x + 396, self.y + 11)
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
	love.graphics.draw(internal.valueDisplay, self.x + 668, self.y + 20)
end

return numberSetting
