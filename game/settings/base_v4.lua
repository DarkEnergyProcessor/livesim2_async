-- Base setting ui item
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local mainFont = require("font")

local baseSettingItem = Luaoop.class("Livesim2.SettingItem.Base")

-- The height of setting is 36

-- must be async (and called at least)
function baseSettingItem:__construct(name)
	assert(coroutine.running(), "must be called from async function")

	local internal = Luaoop.class.data(self)
	local font = mainFont.get(22)
	internal.title = love.graphics.newText(font)
	internal.title:add({color.black, name})

	self.x = 0
	self.y = 0
	self.changedCallback = nil
	self.changedOpaque = nil
end

function baseSettingItem:update(dt)
	return self
end

function baseSettingItem:_emitChangedCallback(v)
	if self.changedCallback then
		return self.changedCallback(self.changedOpaque, v)
	end
end

function baseSettingItem:getValue()
	return nil
end

function baseSettingItem:setValue(v)
	return self
end

function baseSettingItem:setChangedCallback(opaque, func)
	self.changedCallback = func
	self.changedOpaque = opaque
	return self
end

function baseSettingItem:setPosition(x, y)
	self.x, self.y = x, y
	self:_positionChanged()
	return self
end

function baseSettingItem:_positionChanged()
end

-- must be called before drawing your own gui (automatically set color to white)
function baseSettingItem:draw()
	local internal = Luaoop.class.data(self)
	love.graphics.setColor(color.white)
	love.graphics.draw(internal.image, self.x, self.y)
	love.graphics.draw(internal.title, self.x + 5, self.y + 16)
	return self
end

return baseSettingItem
