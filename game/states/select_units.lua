-- Unit Selection Menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local utf8 = require("utf8")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")
local Async = require("async")
local color = require("color")
local MainFont = require("main_font")
local L = require("language")

local Glow = require("game.afterglow")
local BackgroundLoader = require("game.background_loader")
local BackNavigation = require("game.ui.back_navigation")

local selectUnits = Gamestate.create {
	images = {}, fonts = {}
}

local unitButton = Luaoop.class("Livesim2.UnitSelectButtonUI", Glow.Element)

function unitButton:new(image, name)
	local font = MainFont.get(22)
	local textBuilder = {}

	-- break text
	do
		local txt = {}
		for _, c in utf8.codes(name) do
			txt[#txt + 1] = utf8.char(c)
			local cat = table.concat(txt)

			if font:getWidth(cat) >= 174 then
				textBuilder[#textBuilder + 1] = cat

				for j = #txt, 1, -1 do
					txt[j] = nil
				end
			end
		end

		if #txt > 0 then
			textBuilder[#textBuilder + 1] = table.concat(txt)
		end
	end

	local usedText = table.concat(textBuilder, "\n")
	self.width, self.height = 310, 128
	self.isPressed = false
	self.unit = image
	self.text = love.graphics.newText(font)
	self.text:add({color.black, usedText}, 128, 64 - font:getHeight() * #textBuilder * 0.5)

	self:addEventListener("mousepressed", unitButton._pressed)
	self:addEventListener("mousecanceled", unitButton._released)
	self:addEventListener("mousereleased", unitButton._released)
end

function unitButton:_pressed()
	self.isPressed = true
end

function unitButton:_released()
	self.isPressed = false
end

function unitButton:render(x, y)
	love.graphics.setColor(self.isPressed and color.white75PT or color.white50PT)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.rectangle("line", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.unit, x + 64, y + 64, 0, 112/128, 112/128, 64, 64)
	love.graphics.draw(self.text, x, y)
end

local function leave()
	return Gamestate.leave(nil)
end

local function unitButtonPressed(_, value)
	value.reference.value = value.name
	return leave()
end

function selectUnits:load()
	Glow.clear()

	if self.data.frame == nil then
		self.data.frame = Glow.Frame(0, 68, 960, 572) -- horizontal working space actually 930
	end
	self.data.frame:clear()
	Glow.addFrame(self.data.frame)

	if self.data.background == nil then
		self.data.background = BackgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = BackNavigation(L"changeUnits:selectUnits")
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 0, 0)
end

local function generateFrame(self, ref, unitListTemp)
	for i, v in ipairs(unitListTemp) do
		local x, y = (i - 1) % 3, math.floor((i - 1) / 3)
		local elem = unitButton(v.image, v.name)
		elem:addEventListener("mousereleased", unitButtonPressed)
		elem:setData({reference = ref, name = v.name})
		self.data.frame:addElement(elem, x * 310, y * 128)
	end
end

function selectUnits:start(arg)
	-- arg[1] contains all loaded unit images
	-- arg[2] is location to put the images, arg[2].value is key to assign
	local unitListTemp = {}
	for k, v in pairs(arg[1]) do
		unitListTemp[#unitListTemp + 1] = {
			name = k,
			image = v
		}
	end

	-- sort things
	table.sort(unitListTemp, function(a, b)
		return a.name < b.name
	end)

	Async.runFunction(generateFrame):run(self, arg[2], unitListTemp)
end

function selectUnits:update(dt)
	return self.data.frame:update(dt)
end

function selectUnits:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)

	self.data.frame:draw()
	Glow.draw()
end

selectUnits:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return selectUnits
