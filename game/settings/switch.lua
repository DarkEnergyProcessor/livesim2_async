-- Setting switch item (on/off)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local assetCache = require("asset_cache")
local setting = require("setting")
local Luaoop = require("libs.Luaoop")
local baseSetting = require("game.settings.base")

local glow = require("game.afterglow")
local toggleButton = require("game.ui.toggle_button")

local defaultOnOffValue = {
	on = 1,
	off = 0
}

local switchSetting = Luaoop.class("Livesim2.SettingItem.Switch", baseSetting)

local function onButtonReleased(elem, switch)
	local internal = Luaoop.class.data(switch)

	if internal.settingName then
		setting.set(internal.settingName, internal.onOffValue.on)
	end

	elem.active = true
	internal.off.active = false
	internal.value = internal.onOffValue.on
	switch:_emitChangedCallback(internal.onOffValue.on)
end

local function offButtonReleased(elem, switch)
	local internal = Luaoop.class.data(switch)

	if internal.settingName then
		setting.set(internal.settingName, internal.onOffValue.off)
	end

	elem.active = true
	internal.on.active = false
	internal.value = internal.onOffValue.off
	switch:_emitChangedCallback(internal.onOffValue.off)
end

function switchSetting:__construct(name, settingName, onoffValue)
	baseSetting.__construct(self, name)

	local internal = Luaoop.class.data(self)
	local images = assetCache.loadMultipleImages({
		"assets/image/ui/set_button_14.png",
		"assets/image/ui/set_button_14se.png",
		"assets/image/ui/set_button_15.png",
		"assets/image/ui/set_button_15se.png"
	}, {mipmaps = true})

	internal.settingName = settingName
	internal.onOffValue = onoffValue or defaultOnOffValue
	internal.on = toggleButton(images)
	internal.on:addEventListener("mousereleased", onButtonReleased)
	internal.on:setData(self)
	glow.addElement(internal.on, self.x + 569, self.y + 19)
	internal.off = toggleButton({select(3, unpack(images))})
	internal.off:addEventListener("mousereleased", offButtonReleased)
	internal.off:setData(self)
	glow.addElement(internal.off, self.x + 669, self.y + 19)

	local value
	if settingName then
		value = tostring(setting.get(settingName))
	else
		value = tostring(internal.onOffValue.value)
	end

	if value == tostring(internal.onOffValue.on) then
		internal.value = internal.onOffValue.on
		internal.on.active = true
	elseif value == tostring(internal.onOffValue.off) then
		internal.value = internal.onOffValue.off
		internal.off.active = true
	end
end

function switchSetting:__destruct()
	local internal = Luaoop.class.data(self)

	glow.removeElement(internal.on)
	glow.removeElement(internal.off)
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
		internal.value = internal.onOffValue.on
		internal.on.active = true
		internal.off.active = false
	elseif v == tostring(internal.onOffValue.off) then
		internal.value = internal.onOffValue.off
		internal.off.active = true
		internal.on.active = false
	else
		error("invalid value", 2)
	end

	return self
end

function switchSetting:_positionChanged()
	local internal = Luaoop.class.data(self)
	glow.setElementPosition(internal.on, self.x + 569, self.y + 19)
	glow.setElementPosition(internal.off, self.x + 669, self.y + 19)
end

return switchSetting
