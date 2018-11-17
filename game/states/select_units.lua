-- Unit Selection Menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local utf8 = require("utf8")
local Luaoop = require("libs.Luaoop")

local gamestate = require("gamestate")
local async = require("async")
local color = require("color")
local mainFont = require("font")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")

local selectUnits = gamestate.create {
	images = {}, fonts = {}
}

local unitButton = Luaoop.class("Livesim2.UnitSelectButtonUI", glow.element)

function unitButton:new(image, name)
	local font = mainFont.get(22)
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
	return gamestate.leave(nil)
end

local function unitButtonPressed(_, value)
	value.reference.value = value.name
	return leave()
end

function selectUnits:load()
	glow.clear()

	if self.data.frame == nil then
		self.data.frame = glow.frame(0, 68, 960, 572) -- horizontal working space actually 930
	end
	self.data.frame:clear()
	glow.addFrame(self.data.frame)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"changeUnits:selectUnits")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 0, 0)
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

	async.runFunction(generateFrame):run(self, arg[2], unitListTemp)
end

function selectUnits:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)

	self.data.frame:draw()
	glow.draw()
end

selectUnits:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return selectUnits
