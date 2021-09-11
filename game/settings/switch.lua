-- Setting switch item (on/off)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local Setting = require("setting")
local baseSetting = require("game.settings.base")

local Glow = require("game.afterglow")
local colorTheme = require("game.color_theme")

local switchSetting = Luaoop.class("Livesim2.SettingItem.Switch", baseSetting)
local switchUI = Luaoop.class("Livesim2.SettingItem.SwitchUI", Glow.Element)

local interpolation = require("libs.cubic_bezier")(0.4, 0, 0.2, 1):getFunction()

local defaultOnOffValue = {
	on = 1,
	off = 0
}

function switchUI:new()
	self.width = 160
	self.height = 36
	self.checked = false
	self.position = 0

	self:addEventListener("mousereleased", switchUI._switch)
end

function switchUI:_switch()
	self.checked = not(self.checked)
	self:triggerEvent("checked", self.checked)
end

function switchUI:update(dt)
	self.position = math.min(math.max(self.position + dt * (self.checked and 4 or -4), 0), 1)
end

function switchUI:isChecked()
	return self.checked
end

function switchUI:setChecked(checked)
	self.checked = not(not(checked))
end

function switchUI:setCheckedDirect(checked)
	local v = not(not(checked))
	self.checked = v
	self.position = v and 1 or 0
end

function switchUI:render(x, y)
	local col = self.checked and colorTheme.get() or color.hex7F7F7F
	local offset = interpolation(self.position) * 112
	love.graphics.setColor(col)
	love.graphics.rectangle("line", x, y, self.width, self.height, 18, 18)
	love.graphics.rectangle("fill", x + 4 + offset, y + 4, 40, 28, 14, 14)
	love.graphics.rectangle("line", x + 4 + offset, y + 4, 40, 28, 14, 14)
end

local function valueChanged(_, switch, value)
	local internal = Luaoop.class.data(switch)
	local idx = internal.onOffValue[value and "on" or "off"]

	if internal.settingName then
		Setting.set(internal.settingName, idx)
	end

	switch:_emitChangedCallback(idx)
end

function switchSetting:__construct(frame, name, settingName, onoffValue)
	baseSetting.__construct(self, name)

	local internal = Luaoop.class.data(self)
	internal.settingName = settingName
	internal.onOffValue = onoffValue or defaultOnOffValue
	internal.frame = assert(frame)
	internal.ui = switchUI()
	internal.ui:addEventListener("checked", valueChanged)
	internal.ui:setData(self)
	frame:addElement(internal.ui, self.x + 420, self.y)

	local value
	local set = Setting.get(settingName)
	if settingName then
		value = tostring(set)
	else
		value = tostring(internal.onOffValue.value)
	end

	internal.value = value
	internal.ui:setCheckedDirect(value == tostring(internal.onOffValue.on))
end

function switchSetting:__destruct()
	local internal = Luaoop.class.data(self)
	internal.frame:removeElement(internal.ui)
end

function switchSetting:getValue()
	return Luaoop.class.data(self).value
end

function switchSetting:setValue(v)
	local internal = Luaoop.class.data(self)

	if type(v) == "boolean" then
		v = v and tostring(internal.onOffValue.on) or tostring(internal.onOffValue.off)
	end

	if v == tostring(internal.onOffValue.on) then
		internal.ui:setChecked(true)
	elseif v == tostring(internal.onOffValue.off) then
		internal.ui:setChecked(false)
	else
		error("invalid value", 2)
	end

	return self
end

function switchSetting:_positionChanged()
	local internal = Luaoop.class.data(self)
	internal.frame:setElementPosition(internal.ui, self.x + 420, self.y)
end

return switchSetting
