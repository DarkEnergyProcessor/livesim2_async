-- Card picker: grid of all cards, tap one to put it in a lane
-- Part of the SIF gift fork

local love = require("love")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")
local Async = require("async")

local Glow = require("game.afterglow")
local Sleek = require("game.ui.sleek")
local cards = require("game.cards")

local cardPicker = Gamestate.create {
	images = {},
	fonts = {},
}

local COLS = 4
local TILE_W, TILE_H, GAP = 211, 160, 14
local FRAME_X, FRAME_Y = 20, 88

---------------------------------------------------------------- tile

local cardTile = Luaoop.class("Livesim2.CardPickTile", Glow.Element)

function cardTile:new(card, image, inLane, isCurrent)
	self.width, self.height = TILE_W, TILE_H
	self.card = card
	self.image = image
	self.inLane = inLane
	self.isCurrent = isCurrent
	self.isPressed = false
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

local function fmt(n)
	local s = tostring(math.floor(n + 0.5))
	return s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
end

function cardTile:render(x, y)
	local c = self.card
	Sleek.panel(x, y, self.width, self.height, 22, {
		borderColor = self.isCurrent and Sleek.color.accent or nil,
		borderWidth = self.isCurrent and 2 or 1,
	})

	if c.blank then
		local cx, cy = x + self.width / 2, y + 62
		Sleek.setColor(Sleek.color.border)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", cx, cy, 30, 48)
		love.graphics.line(cx - 10, cy, cx + 10, cy)
		love.graphics.setLineWidth(1)
		Sleek.setColor(Sleek.color.muted)
		love.graphics.setFont(Sleek.font(16))
		love.graphics.printf("Empty lane", x, y + 106, self.width, "center")
	else
		Sleek.drawCard(c, self.image, x + 16 + 30, y + 16 + 30, 30, {shadow = false})

		local nx = x + 16 + 60 + 12
		love.graphics.setFont(Sleek.font(18, "medium"))
		Sleek.setColor(Sleek.color.text)
		local name = c.name
		local maxW = self.width - (nx - x) - 12
		local font = love.graphics.getFont()
		while font:getWidth(name) > maxW and #name > 1 do
			name = name:sub(1, -2)
		end
		if name ~= c.name then name = name:sub(1, -2).."…" end
		love.graphics.print(name, nx, y + 18)

		local style = Sleek.rarityStyle(c.rarity)
		local cw = Sleek.chip(c.rarity:upper(), nx, y + 48, style.chipBg, style.chipFg, 11)
		if self.inLane then
			love.graphics.setFont(Sleek.font(12))
			Sleek.setColor(Sleek.color.muted)
			love.graphics.print("Lane "..self.inLane, nx + cw + 8, y + 49)
		end

		-- stats row
		Sleek.setColor(Sleek.color.track)
		love.graphics.rectangle("fill", x + 16, y + 98, self.width - 32, 1)
		local colW = (self.width - 32) / 3
		local labels = {"APPEAL", "STAMINA", "TECH"}
		local vals = {c.appeal, c.stamina, c.tech}
		for i = 1, 3 do
			local sx = x + 16 + (i - 1) * colW
			love.graphics.setFont(Sleek.font(10, "medium"))
			Sleek.setColor(Sleek.color.muted)
			love.graphics.print(labels[i], sx, y + 108)
			love.graphics.setFont(Sleek.font(16, "medium"))
			Sleek.setColor(Sleek.color.text)
			love.graphics.print(fmt(vals[i]), sx, y + 124)
		end
	end

	if self.isPressed then
		love.graphics.setColor(0, 0, 0, 0.05)
		love.graphics.rectangle("fill", x, y, self.width, self.height, 22, 22, 32)
	end
end

---------------------------------------------------------------- state

local function leave()
	return Gamestate.leave(nil)
end

function cardPicker:load()
	Glow.clear()
	Sleek.loadTheme()

	if self.data.frame == nil then
		self.data.frame = Glow.Frame(FRAME_X, FRAME_Y, 960 - FRAME_X * 2, 640 - FRAME_Y)
	end
	self.data.frame:clear()
	Glow.addFrame(self.data.frame)

	if self.data.back == nil then
		self.data.back = Sleek.backButton()
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 24, 16)
end

local function buildList(self, result)
	local ids = cards.getTeamIds()
	local inUse = {}
	for i, id in ipairs(ids) do if id ~= "" then inUse[id] = 10 - i end end
	local currentId = result.slot and ids[result.slot] or nil

	local list = cards.getSorted(true)
	table.insert(list, 1, {id = "", name = "(empty)", blank = true})
	for i, c in ipairs(list) do
		local image = (not c.blank) and cards.loadImage(c) or nil
		local elem = cardTile(c, image, inUse[c.id], currentId ~= nil and c.id == currentId and not c.blank)
		elem:addEventListener("mousereleased", function()
			result.picked = c.id
			return leave()
		end)
		local col = (i - 1) % COLS
		local row = math.floor((i - 1) / COLS)
		self.data.frame:addElement(elem, 4 + col * (TILE_W + GAP), row * (TILE_H + GAP) + 4)
	end
	self.persist.count = #list - 1
end

function cardPicker:start(result)
	-- reload card files so edits show up without restarting
	cards.getAll(true)
	self.persist.lane = result and result.slot and (10 - result.slot) or nil
	self.persist.count = 0
	self.data.frame:clear()
	Async.runFunction(buildList):run(self, result or {})
end

function cardPicker:update(dt)
	self.data.frame:update(dt)
	Sleek.slimScrollbars(self.data.frame)
end

function cardPicker:draw()
	Sleek.background("plain")
	self.data.frame:draw()
	-- header over the scrolled content
	Sleek.setColor(Sleek.color.bg)
	love.graphics.rectangle("fill", -88, -43, 1136, FRAME_Y + 43)
	Sleek.header("Pick a card", self.persist.lane and ("Lane "..self.persist.lane) or nil)
	if self.persist.count > 0 then
		love.graphics.setFont(Sleek.font(13))
		Sleek.setColor(Sleek.color.muted)
		local t = self.persist.count == 1 and "1 card" or (self.persist.count.." cards")
		love.graphics.printf(t, 0, 36, 936, "right")
	end
	Glow.draw()
end

cardPicker:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return cardPicker
