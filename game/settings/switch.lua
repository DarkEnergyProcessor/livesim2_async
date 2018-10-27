-- Setting switch item (on/off)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local assetCache = require("asset_cache")
local setting = require("setting")
local gui = require("libs.fusion-ui")
local Luaoop = require("libs.Luaoop")
local baseSetting = require("game.settings.base")

local defaultOnOffValue = {
	on = 1,
	off = 0
}
local switchButtons = {init = false}

local switchSetting = Luaoop.class("settingitem.Switch", baseSetting)

function switchSetting:__construct(name, settingName, onoffValue)
	local internal = switchSetting^self

	if not(switchButtons.init) then
		local images = assetCache.loadMultipleImages({
			"assets/image/ui/set_button_14.png",
			"assets/image/ui/set_button_14se.png",
			"assets/image/ui/set_button_15.png",
			"assets/image/ui/set_button_15se.png"
		}, {mipmaps = true})
		local normalOnStyle = {
			backgroundImage = images[1],
			backgroundSize = 'fit',
			foregroundColor = {255, 255, 255, 255},
			backgroundColor = {0, 0, 0, 0},
			backgroundImageColor = {255, 255, 255, 255},
		}
		local selectedOnStyle = {
			backgroundImage = images[2],
			backgroundSize = 'fit',
			foregroundColor = {255, 255, 255, 255},
			backgroundColor = {0, 0, 0, 0},
			backgroundImageColor = {255, 255, 255, 255},
		}
		local normalOffStyle = {
			backgroundImage = images[3],
			backgroundSize = 'fit',
			foregroundColor = {255, 255, 255, 255},
			backgroundColor = {0, 0, 0, 0},
			backgroundImageColor = {255, 255, 255, 255},
		}
		local selectedOffStyle = {
			backgroundImage = images[4],
			backgroundSize = 'fit',
			foregroundColor = {255, 255, 255, 255},
			backgroundColor = {0, 0, 0, 0},
			backgroundImageColor = {255, 255, 255, 255},
		}
		switchButtons.on = gui.template.new("button", normalOnStyle)
		switchButtons.on:addStyleSwitch("selected", "unselected", selectedOnStyle)
		switchButtons.off = gui.template.new("button", normalOffStyle)
		switchButtons.off:addStyleSwitch("selected", "unselected", selectedOffStyle)
		switchButtons.init = true
	end

	internal.onOffValue = onoffValue or defaultOnOffValue
	internal.on = switchButtons.on:newElement("")
	internal.on:addEventListener("released", function()
		internal.on:emitEvent("selected")
		internal.off:emitEvent("unselected")
		if settingName then setting.set(settingName, internal.onOffValue.on) end
		self:_emitChangedCallback(internal.onOffValue.on)
	end)
	internal.on:addEventListener("selected", function()
		if settingName then setting.set(settingName, internal.onOffValue.on) end
		internal.value = internal.onOffValue.on
		self:_emitChangedCallback(internal.onOffValue.on)
	end)
	internal.off = switchButtons.off:newElement("")
	internal.off:addEventListener("released", function()
		internal.off:emitEvent("selected")
		internal.on:emitEvent("unselected")
	end)
	internal.off:addEventListener("selected", function()
		if settingName then setting.set(settingName, internal.onOffValue.off) end
		internal.value = internal.onOffValue.off
		self:_emitChangedCallback(internal.onOffValue.off)
	end)

	local value
	if settingName then
		value = tostring(setting.get(settingName))
	else
		value = tostring(internal.onOffValue.value)
	end

	if value == tostring(internal.onOffValue.on) then
		internal.value = internal.onOffValue.on
		internal.on:emitEvent("selected")
	elseif value == tostring(internal.onOffValue.off) then
		internal.value = internal.onOffValue.off
		internal.off:emitEvent("selected")
	end

	return baseSetting.__construct(self, name)
end

function switchSetting:getValue()
	local internal = switchSetting^self
	return internal.value
end

function switchSetting:setValue(v)
	local internal = switchSetting^self

	if type(v) == "boolean" then
		v = v and tostring(internal.onOffValue.on) or tostring(internal.onOffValue.off)
	end

	if v == tostring(internal.onOffValue.on) then
		internal.value = internal.onOffValue.on
		internal.on:emitEvent("selected")
		internal.off:emitEvent("unselected")
	elseif v == tostring(internal.onOffValue.off) then
		internal.value = internal.onOffValue.off
		internal.off:emitEvent("selected")
		internal.on:emitEvent("unselected")
	else
		error("invalid value", 2)
	end

	return self
end

function switchSetting:draw()
	local internal = switchSetting^self

	baseSetting.draw(self)
	internal.on:draw(self.x + 569, self.y + 19, 100, 42)
	internal.off:draw(self.x + 669, self.y + 19, 100, 42)
	return self
end

return switchSetting
