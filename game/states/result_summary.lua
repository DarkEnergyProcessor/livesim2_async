-- Live result display (sleek restyle for the SIF gift fork)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local lsr = require("libs.lsr")
local CubicBezier = require("libs.cubic_bezier")

local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local Util = require("util")
local L = require("language")

local Glow = require("game.afterglow")
local Sleek = require("game.ui.sleek")
local cards = require("game.cards")

local interpolation = CubicBezier(0.4, 0, 0.2, 1):getFunction()
local mipmaps = {mipmaps = true}

-- layout
local TOP_Y, TOP_H = 72, 208
local LEFT_W = 360
local BOT_Y, BOT_H = 296, 260
local GRAPH_X, GRAPH_Y, GRAPH_W, GRAPH_H = 32 + 24 + 64, BOT_Y + 92, 896 - 48 - 64, 140
local BTN_Y, BTN_H = 572, 48

local judgementRows = {
	{"perfect", "PERFECT", "accent"},
	{"great", "GREAT", "blue"},
	{"good", "GOOD", "green"},
	{"bad", "BAD", "gold"},
	{"miss", "MISS", "faint"},
}

local resultScreen = Gamestate.create {
	fonts = {},
	images = {},
}

local function fmt(n)
	local s = tostring(math.floor(n + 0.5))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

local function showText(self, text)
	self.persist.statusString = text
	self.persist.statusTimer = 0
end

local function leave()
	Gamestate.leave(LoadingInstance.getInstance())
end

local function skipResultTween(self)
	if not(self) then return end
	self.persist.graphTimer = 3
end

local function pill(text, fill, textColor, border)
	local font = Sleek.font(16, "medium")
	return Sleek.Button({
		w = font:getWidth(text) + 52, h = BTN_H, text = text, size = 16,
		fill = fill, textColor = textColor, border = border,
	})
end

function resultScreen:load(arg)
	-- arg contains:
	-- * name - beatmap name
	-- * summary - beatmap summary
	-- * replay - replay object
	-- * livesim2 - Live Simulator: 2 argument (or nil)
	-- * allowRetry - Allow hold to retry?
	-- * allowSave - Allow replay savig?
	-- * autoplay - Is result from autoplay?
	-- * comboRange - Score and combo range
	-- * background - Beatmap background
	-- * cardStats - per-lane card stats (only right after a song)
	Glow.clear()
	Sleek.loadTheme()

	local saveAllowed = arg.allowSave and not(arg.autoplay)

	if self.data.back == nil then
		self.data.back = Sleek.backButton()
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 24, 16)

	local buttons = {}

	if saveAllowed and self.data.saveReplay == nil then
		self.data.saveReplay = pill("Save replay", Sleek.color.panel, Sleek.color.text, true)
		self.data.saveReplay:addEventListener("mousereleased", function()
			local name
			if not(love.filesystem.createDirectory("replays/"..arg.name)) then
				showText(self, L"livesim2:replay:errorDirectory")
				return
			end

			if arg.replay.filename then
				showText(self, L"livesim2:replay:errorAlreadySaved")
				return
			end

			name = "replays/"..arg.name.."/"..arg.replay.timestamp..".lsr"
			if Util.fileExists(name) then
				showText(self, L"livesim2:replay:errorAlreadySaved")
				return
			end

			local s = lsr.saveReplay(
				name,
				arg.summary.hash,
				arg.replay,
				arg.replay.accuracy,
				arg.replay.events
			)
			if s then
				arg.replay.filename = name
				showText(self, L"livesim2:replay:saved")
			else
				showText(self, L"livesim2:replay:errorSaveGeneric")
			end
		end)
	end
	if self.data.saveReplay then buttons[#buttons + 1] = self.data.saveReplay end

	if not(arg.autoplay) and self.data.showReplay == nil then
		self.data.showReplay = pill("Watch replay", Sleek.color.panel, Sleek.color.text, true)
		self.data.showReplay:addEventListener("mousereleased", function()
			Gamestate.replace(LoadingInstance.getInstance(), "livesim2", {
				summary = arg.summary,
				beatmapName = arg.name,
				replay = arg.replay,
				allowRetry = not(arg.allowRetry),
			})
		end)
	end
	if self.data.showReplay then buttons[#buttons + 1] = self.data.showReplay end

	if self.data.songs == nil then
		self.data.songs = pill("Songs", Sleek.color.panel, Sleek.color.text, true)
		self.data.songs:addEventListener("mousereleased", leave)
	end
	buttons[#buttons + 1] = self.data.songs

	if arg.allowRetry and self.data.reloadLive == nil then
		local font = Sleek.font(16, "medium")
		self.data.reloadLive = Sleek.Button({
			w = font:getWidth("Retry") + 80, h = BTN_H, text = "Retry", size = 16, textOffset = 12,
			fill = Sleek.color.accent, textColor = Sleek.color.white, shadow = true,
			icon = function(x, y, w, h)
				Sleek.iconRetry(x + w / 2 - font:getWidth("Retry") / 2 - 8, y + h / 2, 22, Sleek.color.white)
			end
		})
		self.data.reloadLive:addEventListener("mousereleased", function()
			-- It may contain replay data, but the table may used somewhere
			-- so clone it first.
			local newArg = {}
			for k, v in pairs(arg.livesim2) do
				newArg[k] = v
			end
			newArg.replay = nil

			return Gamestate.replace(LoadingInstance.getInstance(), "livesim2", newArg)
		end)
	end
	if self.data.reloadLive then buttons[#buttons + 1] = self.data.reloadLive end

	-- right-aligned row
	local x = 928
	for i = #buttons, 1, -1 do
		x = x - buttons[i].width
		Glow.addFixedElement(buttons[i], x, BTN_Y)
		x = x - 12
	end
end

local function rankFor(score, range)
	if not range then return nil end
	if score >= range[4] then return "S"
	elseif score >= range[3] then return "A"
	elseif score >= range[2] then return "B"
	elseif score >= range[1] then return "C"
	end
	return "D"
end

local function buildGraph(self, accuracyData)
	-- the original live clear graph: one point per note, 1 = perfect .. 0 = miss
	local canvas = Util.newCanvas(GRAPH_W, GRAPH_H, nil, true)
	local pad = 8
	local lines = {}
	local h = GRAPH_H - pad * 2
	if #accuracyData == 0 then
		lines = {0, GRAPH_H - pad, GRAPH_W, GRAPH_H - pad}
	elseif #accuracyData == 1 then
		local v = accuracyData[1]
		lines = {0, pad + (1 - v) * h, GRAPH_W, pad + (1 - v) * h}
	else
		local n = math.floor(GRAPH_W)
		for i = 1, n do
			local idx = (i - 1) / (n - 1) * (#accuracyData - 1)
			local v0 = accuracyData[math.floor(idx) + 1]
			local v1 = accuracyData[math.ceil(idx) + 1] or accuracyData[#accuracyData]
			local t = idx % 1
			local v = (1 - t) * v0 + t * v1
			lines[#lines + 1] = i - 1
			lines[#lines + 1] = pad + (1 - v) * h
		end
	end

	love.graphics.push("all")
	love.graphics.reset()
	love.graphics.setCanvas(canvas)
	love.graphics.clear(0, 0, 0, 0)
	Sleek.setColor(Sleek.color.accent)
	love.graphics.setLineWidth(2.5)
	love.graphics.setLineJoin("bevel")
	love.graphics.line(lines)
	love.graphics.pop()

	self.persist.graphCanvas = canvas
	self.persist.graphPad = pad
end

function resultScreen:start(arg)
	self.persist.statusTimer = 5.7
	self.persist.statusString = ""
	self.persist.replay = arg.replay
	self.persist.cardStats = arg.cardStats
	self.persist.isLive = arg.livesim2 ~= nil
	self.persist.name = arg.summary.name or arg.name or ""
	self.persist.scoreRange = arg.summary.scoreS and {
		arg.summary.scoreC,
		arg.summary.scoreB,
		arg.summary.scoreA,
		arg.summary.scoreS,
	}
	self.persist.rank = rankFor(arg.replay.score, self.persist.scoreRange)
	self.persist.comboWeight = math.max(arg.replay.perfect + arg.replay.great + arg.replay.good + arg.replay.bad + arg.replay.miss, 1)
	self.persist.graphTimer = 0 -- up to 3 seconds
	self.persist.graphShader = love.graphics.newShader([[
		extern number p;

		vec4 effect(vec4 color, Image tex, vec2 tc, vec2 _)
		{
			if (tc.x > p)
				discard;
			else
				return Texel(tex, tc) * color;
		}
	]])
	buildGraph(self, arg.replay.accuracy or {})

	-- card images for the lane chart
	if self.persist.cardStats then
		local imgs = {}
		for i = 1, 9 do
			local c = self.persist.cardStats.team[i]
			imgs[i] = c and not c.blank and cards.loadImage(c) or nil
		end
		self.persist.cardImages = imgs
	end
end

function resultScreen:update(dt)
	if self.persist.graphTimer < 3 then
		self.persist.graphTimer = math.min(self.persist.graphTimer + dt, 3)
	end
	if self.persist.statusTimer < 5.7 then
		self.persist.statusTimer = math.min(self.persist.statusTimer + dt, 5.7)
	end
	self.persist.graphShader:send("p", self.persist.graphTimer / 3)
end

local function drawScorePanel(self, ip)
	local info = self.persist.replay
	Sleek.panel(32, TOP_Y, LEFT_W, TOP_H, 28)
	local cx, cy = 32 + 28 + 58, TOP_Y + TOP_H / 2
	Sleek.setColor(Sleek.color.accent)
	love.graphics.setLineWidth(3)
	love.graphics.circle("line", cx, cy, 56, 64)
	love.graphics.setLineWidth(1)
	local rankFont = Sleek.font(64, "light")
	love.graphics.setFont(rankFont)
	if self.persist.graphTimer >= 2.8 then
		local a = interpolation(math.min((self.persist.graphTimer - 2.8) * 5, 1))
		Sleek.setColor(Sleek.color.accent, a)
		love.graphics.printf(self.persist.rank or "–", cx - 56, cy - rankFont:getHeight() / 2, 112, "center")
	end

	local tx = cx + 56 + 24
	love.graphics.setFont(Sleek.font(12, "medium"))
	Sleek.setColor(Sleek.color.muted)
	love.graphics.print("SCORE", tx, cy - 50)
	love.graphics.setFont(Sleek.font(38, "light"))
	Sleek.setColor(Sleek.color.text)
	love.graphics.print(fmt(info.score * ip), tx, cy - 34)

	local stats = self.persist.cardStats
	if stats then
		local f, fb = Sleek.font(14), Sleek.font(14, "medium")
		local yy = cy + 20
		love.graphics.setFont(f)
		Sleek.setColor(Sleek.color.muted)
		love.graphics.print("Crits", tx, yy)
		love.graphics.setFont(fb)
		Sleek.setColor(Sleek.color.text)
		local cw = f:getWidth("Crits ")
		love.graphics.print(tostring(stats.crits), tx + cw, yy)
		local sx = tx + cw + fb:getWidth(tostring(stats.crits)) + 16
		love.graphics.setFont(f)
		Sleek.setColor(Sleek.color.muted)
		love.graphics.print("Skills", sx, yy)
		love.graphics.setFont(fb)
		Sleek.setColor(Sleek.color.text)
		love.graphics.print(tostring(stats.skillFires), sx + f:getWidth("Skills "), yy)
	end
end

local function drawLanePanel(self, ip)
	local x, y, w, h = 32 + LEFT_W + 16, TOP_Y, 896 - LEFT_W - 16, TOP_H
	Sleek.panel(x, y, w, h, 28)
	love.graphics.setFont(Sleek.font(12, "medium"))
	Sleek.setColor(Sleek.color.muted)
	love.graphics.print("SCORE BY LANE", x + 20, y + 18)

	local stats = self.persist.cardStats
	if not stats then
		love.graphics.setFont(Sleek.font(14))
		Sleek.setColor(Sleek.color.faint)
		love.graphics.printf("Only shown right after a song.", x + 20, y + h / 2 - 10, w - 40, "left")
		return
	end

	local maxScore = 1
	for i = 1, 9 do maxScore = math.max(maxScore, stats.laneScore[i]) end
	local colW = (w - 40) / 9
	local baseY = y + h - 16 - 38 -- top of the card circle
	local barMax = baseY - 8 - (y + 58)
	local small = Sleek.font(11)
	for lane = 1, 9 do
		local slot = 10 - lane
		local score = stats.laneScore[slot]
		local cx = x + 20 + (lane - 0.5) * colW
		local bh = math.max(6, barMax * (score / maxScore) * ip)
		Sleek.setColor(score == maxScore and score > 0 and Sleek.color.accent or Sleek.color.grey)
		love.graphics.rectangle("fill", cx - 9, baseY - 8 - bh, 18, bh, 9, 9, 16)
		love.graphics.setFont(small)
		Sleek.setColor(Sleek.color.muted)
		local label = score >= 1000 and (math.floor(score / 1000 + 0.5).."k") or tostring(score)
		love.graphics.printf(label, cx - colW / 2, baseY - 8 - bh - 16, colW, "center")
		local card = stats.team[slot]
		Sleek.drawCard(card, self.persist.cardImages and self.persist.cardImages[slot], cx, baseY + 19, 19, {shadow = false})
	end
end

local function drawJudgementPanel(self, ip)
	local info = self.persist.replay
	local interp = self.persist.graphTimer / 3
	Sleek.panel(32, BOT_Y, 896, BOT_H, 28)

	-- six columns: judgements + combo
	local colW = (896 - 48) / 6
	local labelFont, valueFont, pctFont = Sleek.font(12, "medium"), Sleek.font(26), Sleek.font(12)
	for i = 1, 6 do
		local cx = 32 + 24 + (i - 0.5) * colW
		local label, value, pct, col
		if i <= 5 then
			local row = judgementRows[i]
			local count = math.floor(info[row[1]] * interp + 0.5)
			label, value = row[2], tostring(count)
			pct = string.format("%.2f%%", count / self.persist.comboWeight * 100)
			col = Sleek.color[row[3]]
		else
			label, value, pct, col = "COMBO", fmt(info.maxCombo * ip), "max", Sleek.color.text
		end
		love.graphics.setFont(labelFont)
		local lw = labelFont:getWidth(label)
		Sleek.setColor(col)
		love.graphics.circle("fill", cx - lw / 2 - 8, BOT_Y + 26, 4, 16)
		Sleek.setColor(Sleek.color.muted)
		love.graphics.print(label, cx - lw / 2 + 2, BOT_Y + 18)
		love.graphics.setFont(valueFont)
		Sleek.setColor(Sleek.color.text)
		love.graphics.printf(value, cx - colW / 2, BOT_Y + 34, colW, "center")
		love.graphics.setFont(pctFont)
		Sleek.setColor(Sleek.color.muted)
		love.graphics.printf(pct, cx - colW / 2, BOT_Y + 68, colW, "center")
	end

	-- accuracy graph
	local gx, gy = GRAPH_X, GRAPH_Y
	Sleek.setColor(Sleek.color.track, 0.6)
	love.graphics.rectangle("fill", gx - 6, gy, GRAPH_W + 12, GRAPH_H, 14, 14, 24)
	local pad = self.persist.graphPad
	local h = GRAPH_H - pad * 2
	love.graphics.setFont(Sleek.font(10, "medium"))
	for i, row in ipairs(judgementRows) do
		local ly = gy + pad + (i - 1) / 4 * h
		Sleek.setColor(Sleek.color.border)
		love.graphics.rectangle("fill", gx, math.floor(ly), GRAPH_W, 1)
		Sleek.setColor(Sleek.color.muted)
		love.graphics.printf(row[2], 32 + 16, ly - 6, 64 - 4, "right")
	end
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.setBlendMode("alpha", "premultiplied")
	local prev = love.graphics.getShader()
	love.graphics.setShader(self.persist.graphShader)
	love.graphics.draw(self.persist.graphCanvas, gx, gy)
	love.graphics.setShader(prev)
	love.graphics.setBlendMode("alpha", "alphamultiply")
end

function resultScreen:draw()
	Sleek.background()
	local ip = interpolation(self.persist.graphTimer / 3)

	-- header
	local labelFont = Sleek.font(13, "medium")
	love.graphics.setFont(labelFont)
	Sleek.setColor(Sleek.color.accentDark)
	local label = self.persist.isLive and "LIVE CLEAR" or "REPLAY"
	love.graphics.print(label, 84, 30)
	local titleFont = Sleek.font(24, "medium")
	love.graphics.setFont(titleFont)
	Sleek.setColor(Sleek.color.text)
	local tx = 84 + labelFont:getWidth(label) + 14
	love.graphics.print(self.persist.name, tx, 22)

	drawScorePanel(self, ip)
	drawLanePanel(self, ip)
	drawJudgementPanel(self, ip)

	-- status line (replay saved etc.)
	if self.persist.statusTimer < 5.7 and #self.persist.statusString > 0 then
		local t = self.persist.statusTimer
		local a = t < 0.2 and (t * 5) or (t >= 5.2 and (1 - (t - 5.2) * 2) or 1)
		love.graphics.setFont(Sleek.font(15))
		Sleek.setColor(Sleek.color.muted, a)
		love.graphics.print(self.persist.statusString, 36, BTN_Y + 14)
	end

	return Glow.draw()
end

resultScreen:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

resultScreen:registerEvent("mousepressed", function(self, _, _, b, ist)
	if ist or b <= 2 then
		return skipResultTween(self)
	end
end)

return resultScreen
