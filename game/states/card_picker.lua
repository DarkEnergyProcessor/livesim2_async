-- Card picker: list of all cards, tap one to put it in a lane
-- Part of the SIF gift fork

local love = require("love")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")
local Async = require("async")
local color = require("color")
local MainFont = require("main_font")

local Glow = require("game.afterglow")
local BackgroundLoader = require("game.background_loader")
local BackNavigation = require("game.ui.back_navigation")
local cards = require("game.cards")

local mipmap = {mipmaps = true}

local cardPicker = Gamestate.create {
	images = {
		dummyUnit = {"assets/image/dummy.png", mipmap},
	},
	fonts = {},
}

local rarityColor = {
	ur = {1, 0.84, 0.2},
	ssr = {0.75, 0.55, 1},
	sr = {0.55, 0.8, 1},
	r = {0.8, 0.8, 0.8},
}

local cardButton = Luaoop.class("Livesim2.CardPickButton", Glow.Element)

function cardButton:new(card, image, inUse)
	self.width, self.height = 930, 104
	self.card = card
	self.image = image
	self.inUse = inUse
	self.isPressed = false
	self.nameFont = MainFont.get(22)
	self.font = MainFont.get(16)
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

function cardButton:render(x, y)
	local c = self.card
	love.graphics.setColor(self.isPressed and color.white75PT or color.white50PT)
	love.graphics.rectangle("fill", x, y + 2, self.width, self.height - 4, 8, 8)
	if self.image then
		love.graphics.setColor(color.white)
		love.graphics.draw(self.image, x + 8, y + 8, 0, 88 / self.image:getWidth(), 88 / self.image:getHeight())
	end
	love.graphics.setFont(self.nameFont)
	love.graphics.setColor(color.black)
	love.graphics.print(c.name, x + 108, y + 8)
	if c.rarity then
		love.graphics.setColor(rarityColor[c.rarity] or color.white)
		love.graphics.print(c.rarity:upper(), x + 108 + self.nameFont:getWidth(c.name) + 12, y + 8)
	end
	love.graphics.setFont(self.font)
	love.graphics.setColor(color.black)
	if not c.blank then
		love.graphics.print(string.format("Appeal %d   Stamina %d   Tech %d%s%s",
			c.appeal, c.stamina, c.tech, c.critProfile and "   crit profile" or "",
			self.inUse and ("   (in lane "..self.inUse..")") or ""), x + 108, y + 40)
		love.graphics.printf(c.skill and c.skill.text or "No skill", x + 108, y + 64, self.width - 120, "left")
	else
		love.graphics.print("Leave this lane empty", x + 108, y + 40)
	end
end

local function leave()
	return Gamestate.leave(nil)
end

function cardPicker:load()
	Glow.clear()

	if self.data.frame == nil then
		self.data.frame = Glow.Frame(0, 68, 960, 572)
	end
	self.data.frame:clear()
	Glow.addFrame(self.data.frame)

	if self.data.background == nil then
		self.data.background = BackgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = BackNavigation("Pick a card")
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 0, 0)
end

local function buildList(self, result)
	local ids = cards.getTeamIds()
	local inUse = {}
	for i, id in ipairs(ids) do if id ~= "" then inUse[id] = 10 - i end end

	local list = cards.getSorted(true)
	table.insert(list, 1, {id = "", name = "(empty)", blank = true})
	local y = 0
	for _, c in ipairs(list) do
		local image = cards.loadImage(c)
		if not image and not c.blank then
			image = self.assets.images.dummyUnit
		end
		local elem = cardButton(c, image, inUse[c.id])
		elem:addEventListener("mousereleased", function()
			result.picked = c.id
			return leave()
		end)
		self.data.frame:addElement(elem, 15, y)
		y = y + 104
	end
end

function cardPicker:start(result)
	-- reload card files so edits show up without restarting
	cards.getAll(true)
	self.data.frame:clear()
	Async.runFunction(buildList):run(self, result or {})
end

function cardPicker:update(dt)
	return self.data.frame:update(dt)
end

function cardPicker:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	self.data.frame:draw()
	Glow.draw()
end

cardPicker:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return cardPicker
