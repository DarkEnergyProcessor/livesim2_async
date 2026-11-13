-- Team select: assign cards to the 9 lanes
-- Part of the SIF gift fork

local love = require("love")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")
local color = require("color")
local MainFont = require("main_font")

local Glow = require("game.afterglow")
local BackgroundLoader = require("game.background_loader")
local BackNavigation = require("game.ui.back_navigation")
local cards = require("game.cards")

local mipmap = {mipmaps = true}

local teamSelect = Gamestate.create {
	images = {
		dummyUnit = {"assets/image/dummy.png", mipmap},
	},
	fonts = {},
}

-- Same arc as the live screen, scaled down to leave room for the info panel
local ICON = 96
local slotPosition = {}
do
	local live = {{880,160},{849,313},{762,442},{633,529},{480,560},{326,529},{197,442},{110,313},{80,160}}
	for i, p in ipairs(live) do
		local cx = 480 + (p[1] - 480) * 0.9
		local cy = 60 + (p[2] - 160) * 0.65
		slotPosition[i] = {cx - ICON / 2, cy - ICON / 2}
	end
end

local function getCardImage(self, card)
	return cards.loadImage(card) or self.assets.images.dummyUnit
end

---------------------------------------------------------------- slot button

local slotButton = Luaoop.class("Livesim2.TeamSlotButton", Glow.Element)

function slotButton:new(state, slot)
	self.width, self.height = ICON, ICON
	self.state = state
	self.slot = slot
	self.isPressed = false
	self.font = MainFont.get(16)
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

function slotButton:render(x, y)
	local card = self.state.persist.team[self.slot]
	local image = getCardImage(self.state, card)
	local selected = self.state.persist.selected == self.slot
	local h = ICON / 2
	love.graphics.setColor(self.isPressed and color.white75PT or color.white)
	love.graphics.draw(image, x + h, y + h, 0, ICON / image:getWidth(), ICON / image:getHeight(), image:getWidth() / 2, image:getHeight() / 2)
	love.graphics.setColor(selected and color.hexFFDF35 or color.white50PT)
	love.graphics.setLineWidth(selected and 4 or 2)
	love.graphics.circle("line", x + h, y + h, h - 2)
	love.graphics.setLineWidth(1)
	-- lane number
	love.graphics.setColor(color.black75PT)
	love.graphics.circle("fill", x + ICON - 12, y + ICON - 12, 13)
	love.graphics.setColor(color.white)
	love.graphics.setFont(self.font)
	love.graphics.printf(tostring(10 - self.slot), x + ICON - 26, y + ICON - 22, 28, "center")
end

---------------------------------------------------------------- state

local function leave()
	return Gamestate.leave(nil)
end

local function openPicker(self, slot)
	self.persist.selected = slot
	self.persist.pickerResult = {slot = slot}
	Gamestate.enter(nil, "cardPicker", self.persist.pickerResult)
end

local function teamTotals(team)
	local a, s, t = 0, 0, 0
	for _, c in ipairs(team) do a, s, t = a + c.appeal, s + c.stamina, t + c.tech end
	return a, s, t
end

function teamSelect:load()
	Glow.clear()

	if self.data.background == nil then
		self.data.background = BackgroundLoader.load(5)
	end
	if self.data.back == nil then
		self.data.back = BackNavigation("Team")
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 0, 0)

	if self.data.slots == nil then
		self.data.slots = {}
		for i = 1, 9 do
			local b = slotButton(self, i)
			b:addEventListener("mousereleased", function() openPicker(self, i) end)
			self.data.slots[i] = b
		end
	end
	for i = 1, 9 do
		Glow.addFixedElement(self.data.slots[i], slotPosition[i][1], slotPosition[i][2] + 68)
	end

	self.data.titleFont = MainFont.get(26)
	self.data.font = MainFont.get(18)
	self.data.smallFont = MainFont.get(15)
end

function teamSelect:start()
	self.persist.team = cards.getTeam()
	self.persist.selected = self.persist.selected or 5
end

function teamSelect:resumed()
	local r = self.persist.pickerResult
	if r and r.picked ~= nil then
		local ids = cards.getTeamIds()
		ids[r.slot] = r.picked
		cards.setTeamIds(ids)
		self.persist.team = cards.getTeam()
		self.persist.pickerResult = nil
	end
end

function teamSelect:update(dt)
end

function teamSelect:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	Glow.draw()

	-- info panel for the selected slot (center bottom)
	local card = self.persist.team[self.persist.selected]
	local x, y, w = 40, 392, 880
	love.graphics.setColor(color.black50PT)
	love.graphics.rectangle("fill", x, y, w, 200, 12, 12)
	love.graphics.setColor(color.white)
	love.graphics.setFont(self.data.titleFont)
	love.graphics.print(string.format("Lane %d: %s", 10 - self.persist.selected, card.name), x + 16, y + 10)
	love.graphics.setFont(self.data.font)
	local stats = string.format("%s   Appeal %d   Stamina %d   Tech %d%s",
		card.rarity:upper(), card.appeal, card.stamina, card.tech, card.critProfile and "   (crit profile)" or "")
	love.graphics.print(stats, x + 16, y + 48)
	love.graphics.printf("Skill: "..(card.skill and card.skill.text or "none"), x + 16, y + 78, w - 32, "left")
	if card.passives and #card.passives > 0 then
		local p = {}
		for _, e in ipairs(card.passives) do p[#p + 1] = cards.describeEffect(e) end
		love.graphics.setFont(self.data.smallFont)
		love.graphics.printf("Passive: "..table.concat(p, ", "), x + 16, y + 150, w - 32, "left")
	end

	-- team totals
	local a, s, t = teamTotals(self.persist.team)
	love.graphics.setFont(self.data.smallFont)
	love.graphics.setColor(color.white)
	love.graphics.printf(string.format("Team   Appeal %d   HP %d   Tech %d       Tap a lane to change its card", a, s, t), 0, 608, 960, "center")
end

teamSelect:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return teamSelect
