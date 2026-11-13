-- Team select: assign cards to the 9 lanes
-- Part of the SIF gift fork

local love = require("love")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")

local Glow = require("game.afterglow")
local Sleek = require("game.ui.sleek")
local cards = require("game.cards")

local teamSelect = Gamestate.create {
	images = {},
	fonts = {},
}

-- Same arc as the live screen, squashed to leave room for the info panel.
-- Index = team slot (1 = rightmost lane, SIF order).
local SIZE, SIZE_SEL = 84, 96
local slotCenter = {}
do
	local live = {{880,160},{849,313},{762,442},{633,529},{480,560},{326,529},{197,442},{110,313},{80,160}}
	for i, p in ipairs(live) do
		slotCenter[i] = {480 + (p[1] - 480) * 0.92, 132 + (p[2] - 160) * 0.58}
	end
end

local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 32, 426, 896, 198

local function fmt(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

---------------------------------------------------------------- slot button

local slotButton = Luaoop.class("Livesim2.TeamSlotButton", Glow.Element)

function slotButton:new(state, slot)
	self.width, self.height = SIZE_SEL + 16, SIZE_SEL + 16
	self.state = state
	self.slot = slot
	self.isPressed = false
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

function slotButton:render(x, y)
	local card = self.state.persist.team[self.slot]
	local selected = self.state.persist.selected == self.slot
	local r = (selected and SIZE_SEL or SIZE) / 2
	local cx, cy = x + self.width / 2, y + self.height / 2
	Sleek.drawCard(card, (not card.blank) and cards.loadImage(card) or nil, cx, cy, r, {
		selected = selected,
		alpha = self.isPressed and 0.8 or 1,
	})
	-- lane number badge
	local bx, by = cx + r * 0.72, cy + r * 0.72
	Sleek.setColor(Sleek.color.panel)
	love.graphics.circle("fill", bx, by, 12, 32)
	Sleek.setColor(Sleek.color.border)
	love.graphics.circle("line", bx, by, 12, 32)
	Sleek.setColor(Sleek.color.text)
	local font = Sleek.font(12, "medium")
	love.graphics.setFont(font)
	love.graphics.printf(tostring(10 - self.slot), bx - 12, by - font:getHeight() / 2, 24, "center")
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
	Sleek.loadTheme()

	if self.data.back == nil then
		self.data.back = Sleek.backButton()
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 24, 16)

	if self.data.slots == nil then
		self.data.slots = {}
		for i = 1, 9 do
			local b = slotButton(self, i)
			b:addEventListener("mousereleased", function()
				if self.persist.selected == i then
					openPicker(self, i)
				else
					self.persist.selected = i
				end
			end)
			self.data.slots[i] = b
		end
	end
	for i = 1, 9 do
		local b = self.data.slots[i]
		Glow.addFixedElement(b, slotCenter[i][1] - b.width / 2, slotCenter[i][2] - b.height / 2)
	end

	if self.data.change == nil then
		self.data.change = Sleek.Button({
			w = 150, h = 38, text = "Change card", size = 15,
			fill = Sleek.color.accent, textColor = Sleek.color.white,
		})
		self.data.change:addEventListener("mousereleased", function()
			openPicker(self, self.persist.selected)
		end)
	end
	-- sits in the info panel, under the skill text
	Glow.addFixedElement(self.data.change, PANEL_X + 28 + 124 + 28, PANEL_Y + PANEL_H - 20 - 38)
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

local function drawTotals(team)
	local a, s, t = teamTotals(team)
	local items = {{"APPEAL", fmt(a)}, {"HP", fmt(s)}, {"TECH", fmt(t)}}
	local labelFont, valueFont = Sleek.font(12, "medium"), Sleek.font(15, "medium")
	local x = 936
	for i = #items, 1, -1 do
		local lw, vw = labelFont:getWidth(items[i][1]), valueFont:getWidth(items[i][2])
		local w = lw + vw + 8 + 32
		x = x - w
		Sleek.panel(x, 20, w, 36, 18, {shadow = false})
		Sleek.setColor(Sleek.color.muted)
		love.graphics.setFont(labelFont)
		love.graphics.print(items[i][1], x + 16, 20 + (36 - labelFont:getHeight()) / 2 + 1)
		Sleek.setColor(Sleek.color.text)
		love.graphics.setFont(valueFont)
		love.graphics.print(items[i][2], x + 16 + lw + 8, 20 + (36 - valueFont:getHeight()) / 2)
		x = x - 8
	end
end

function teamSelect:draw()
	Sleek.background("plain")
	-- faint arc through the lanes
	Sleek.setColor(Sleek.color.border)
	love.graphics.setLineWidth(2)
	local pts = {}
	for i = 0, 64 do
		local a = i / 64 * math.pi
		pts[#pts + 1] = 480 + math.cos(a) * 368
		pts[#pts + 1] = 132 + math.sin(a) * 232
	end
	love.graphics.line(pts)
	love.graphics.setLineWidth(1)

	Sleek.header("Team", "Tap a lane, then Change card")
	drawTotals(self.persist.team)

	-- info panel for the selected lane
	local slot = self.persist.selected
	local card = self.persist.team[slot]
	Sleek.panel(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 28)
	local pcx, pcy = PANEL_X + 28 + 62, PANEL_Y + PANEL_H / 2
	Sleek.drawCard(card, (not card.blank) and cards.loadImage(card) or nil, pcx, pcy, 62, {shadow = false})

	local tx = PANEL_X + 28 + 124 + 28
	local textW = PANEL_W - (tx - PANEL_X) - 250 - 56
	local nameFont = Sleek.font(30, "medium")
	love.graphics.setFont(nameFont)
	Sleek.setColor(Sleek.color.text)
	love.graphics.print(card.name, tx, PANEL_Y + 20)
	local cx = tx + nameFont:getWidth(card.name) + 12
	local nameMid = PANEL_Y + 20 + nameFont:getHeight() / 2
	if not card.blank then
		local style = Sleek.rarityStyle(card.rarity)
		local cw, ch = Sleek.chip(card.rarity:upper(), cx, nameMid - 10, style.chipBg, style.chipFg, 12)
		cx = cx + cw + 10
	end
	love.graphics.setFont(Sleek.font(13, "medium"))
	Sleek.setColor(Sleek.color.muted)
	love.graphics.print("LANE "..(10 - slot), cx, nameMid - 8)

	local body = Sleek.font(15)
	love.graphics.setFont(body)
	local ty = PANEL_Y + 64
	if card.blank then
		Sleek.setColor(Sleek.color.muted)
		love.graphics.printf("No card in this lane.", tx, ty, textW, "left")
	else
		local skillText = card.skill and card.skill.text or "No skill"
		Sleek.setColor(Sleek.color.text)
		love.graphics.printf({Sleek.color.muted, "Skill: ", Sleek.color.text, skillText}, tx, ty, textW, "left")
		local _, lines = body:getWrap("Skill: "..skillText, textW)
		ty = ty + #lines * body:getHeight() + 4
		if card.passives and #card.passives > 0 then
			local p = {}
			for _, e in ipairs(card.passives) do p[#p + 1] = cards.describeEffect(e) end
			love.graphics.printf({Sleek.color.muted, "Passive: ", Sleek.color.text, table.concat(p, ", ")}, tx, ty, textW, "left")
		end
	end

	-- stats column
	if not card.blank then
		local sx, sy = PANEL_X + PANEL_W - 28 - 250, PANEL_Y + 52
		local stats = {
			{"APPEAL", card.appeal, Sleek.color.accent},
			{"STAMINA", card.stamina, Sleek.color.green},
			{"TECH", card.tech, Sleek.color.blue},
		}
		for i, st in ipairs(stats) do
			local yy = sy + (i - 1) * 32
			love.graphics.setFont(Sleek.font(12, "medium"))
			Sleek.setColor(Sleek.color.muted)
			love.graphics.print(st[1], sx, yy)
			Sleek.bar(sx + 72, yy + 6, 120, 6, st[2] / 6500, st[3])
			love.graphics.setFont(Sleek.font(15, "medium"))
			Sleek.setColor(Sleek.color.text)
			love.graphics.printf(fmt(st[2]), sx + 192, yy - 2, 58, "right")
		end
		if card.critProfile then
			love.graphics.setFont(Sleek.font(12))
			Sleek.setColor(Sleek.color.muted)
			love.graphics.print("Crit profile: +15% crit chance", sx, sy + 96)
		end
	end

	Glow.draw()
end

teamSelect:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return teamSelect
