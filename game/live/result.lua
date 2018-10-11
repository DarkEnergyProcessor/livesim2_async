-- Result screen
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local assetCache = require("asset_cache")
local color = require("color")

local gui = require("libs.fusion-ui")
local longButtonUI = require("game.ui.long_button")
local selectButtonUI = require("game.ui.select_button")

local result = Luaoop.class("livesim2.Result")

local function addTextWithShadow(text, str, x, y, intensity)
	x = x or 0 y = y or 0
	intensity = intensity or 1
	text:add({color.black, str}, x-intensity, y-intensity)
	text:add({color.black, str}, x+intensity, y+intensity)
	text:add({color.white, str}, x, y)
end

-- must be in async
function result:__construct(beatmapName)
	-- images
	self.images = assetCache.loadMultipleImages({
		"noteImage:assets/image/tap_circle/notes.png", -- 1
		"assets/image/live/live_graph.png", -- 2
		"assets/image/live/ef_330_000_1.png", -- 3
		"assets/image/live/ef_313_004_w2x.png", -- 4
		"assets/image/live/ef_313_003_w2x.png",
		"assets/image/live/ef_313_002_w2x.png",
		"assets/image/live/ef_313_001_w2x.png",
		"assets/image/live/ef_313_000_w2x.png",
	}, {mipmaps = true})
	-- fonts
	self.fonts = assetCache.loadMultipleFonts({
		{"fonts/MTLmr3m.ttf", 26},
		{"fonts/MTLmr3m.ttf", 30},
		{"fonts/MTLmr3m.ttf", 40},
	})
	self.tokenQuad = love.graphics.newQuad(14 * 128, 15 * 128, 128, 128, 2048, 2048)
	-- timer
	self.timer = timer.new()
	-- live graph mesh
	self.graphMesh = nil
	-- return button
	self.returnButtonCallback = nil
	self.returnButtonOpaque = nil
	self.returnRetryTimer = -math.huge
	self.returnButton = longButtonUI.new("Return")
	self.returnButton:addEventListener("released", function()
		print(self.returnRetryTimer)
		self.returnButtonCallback(self.returnButtonOpaque, self.returnRetryTimer >= 2)
		self.returnRetryTimer = -math.huge
	end)
	self.returnButton:addEventListener("pressed", function()
		self.returnRetryTimer = 0
		print(self.returnRetryTimer)
	end)
	-- replay button
	self.replayButtonCallback = nil
	self.replayButtonOpaque = nil
	self.replayButton = selectButtonUI.new("Replay")
	self.replayButton:addEventListener("released", function()
		return self.replayButtonCallback(self.replayButtonOpaque)
	end)
	-- save replay button
	self.saveReplayVanishTimer = 0
	self.saveReplayButtonCallback = nil
	self.saveReplayButtonOpaque = nil
	self.saveReplayButton = selectButtonUI.new("Save Replay")
	self.saveReplayButton:addEventListener("released", function()
		-- must return status message
		self.saveReplayStatus = tostring(self.saveReplayButtonCallback(self.saveReplayButtonOpaque))
		self.saveReplayVanishTimer = 3
	end)
	-- text objects
	self.staticText = love.graphics.newText(self.fonts[3])
	addTextWithShadow(self.staticText, "Max Combo", 600, 80)
	addTextWithShadow(self.staticText, "Token", 648, 156)
	addTextWithShadow(self.staticText, "Score", 600, 232)
	self.beatmapNameText = love.graphics.newText(self.fonts[1])
	addTextWithShadow(self.beatmapNameText, beatmapName, 0, 0)
	self.statusText = love.graphics.newText(self.fonts[2])
	self.judgementText = love.graphics.newText(self.fonts[3])
	-- information table
	self.noteInfoTable = nil
	self.displayJudgement = {
		perfect = 0,
		great = 0,
		good = 0,
		bad = 0,
		miss = 0,
		token = 0,
		maxToken = 0,
		combo = 0,
		maxCombo = 0,
		score = 0,
		value = 0,
		comboLevel = ""
	}
end

function result:update(dt)
	self.timer:update(dt)
	self.saveReplayVanishTimer = self.saveReplayVanishTimer - dt
	self.returnRetryTimer = self.returnRetryTimer + dt

	if self.noteInfoTable then
		-- some little animation
		-- left side
		self.judgementText:clear()
		addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.perfect)), 310, 80)
		addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.great)), 310, 144)
		addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.good)), 310, 208)
		addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.bad)), 310, 272)
		addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.miss)), 310, 336)
		-- right side
		self.statusText:clear()
		local comboStatus = self.displayJudgement.value == 1 and self.displayJudgement.comboLevel or ""
		addTextWithShadow(
			self.statusText,
			string.format("%d/%d %s", self.displayJudgement.combo, self.displayJudgement.maxCombo, comboStatus),
			600, 118
		)
		addTextWithShadow(
			self.statusText,
			string.format("%d/%d", self.displayJudgement.token, self.displayJudgement.maxToken),
			600, 198
		)
		addTextWithShadow(
			self.statusText,
			string.format("%d", self.displayJudgement.score),
			600, 278
		)
	end
end

function result:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.images[3], 230, 0)
	-- judgement
	love.graphics.draw(self.images[4], 81, 80, 0, 0.5, 0.5)
	love.graphics.draw(self.images[5], 107, 144, 0, 0.5, 0.5)
	love.graphics.draw(self.images[6], 117, 208, 0, 0.5, 0.5)
	love.graphics.draw(self.images[7], 137, 272, 0, 0.5, 0.5)
	love.graphics.draw(self.images[8], 134, 336, 0, 0.5, 0.5)
	-- token image
	love.graphics.draw(self.images[1], self.tokenQuad, 600, 156, 0, 0.3, 0.3)
	-- live graph
	if self.graphMesh then
		love.graphics.draw(self.graphMesh, 80, 422)
	end
	-- draw text
	love.graphics.draw(self.staticText)
	love.graphics.draw(self.statusText)
	love.graphics.draw(self.judgementText)
	love.graphics.draw(self.beatmapNameText, 80, 396)
	if self.saveReplayVanishTimer > 0 then
		love.graphics.setFont(self.fonts[1])
		love.graphics.setColor(color.black)
		love.graphics.print(self.saveReplayStatus, 599, 393)
		love.graphics.print(self.saveReplayStatus, 601, 395)
		love.graphics.setColor(color.white)
		love.graphics.print(self.saveReplayStatus, 600, 394)
	end

	-- draw buttons (gui)
	selectButtonUI.draw(self.replayButton, 600, 314)
	selectButtonUI.draw(self.saveReplayButton, 600, 356)
	longButtonUI.draw(self.returnButton, 101, 556)
	gui.draw()
end

function result:setInformation(noteinfo, accuracyData, comboRange)
	-- see self.persist.noteInfo in game/states/livesim2.lua
	self.noteInfoTable = noteinfo
	self.displayJudgement.combo = noteinfo.maxCombo
	self.displayJudgement.maxCombo = noteinfo.totalNotes
	self.displayJudgement.maxToken = noteinfo.tokenAmount
	self.timer:tween(1, self.displayJudgement, {
		perfect = noteinfo.perfect,
		great = noteinfo.great,
		good = noteinfo.good,
		bad = noteinfo.bad,
		miss = noteinfo.miss,
		token = noteinfo.token,
		combo = noteinfo.combo,
		score = noteinfo.score,
		value = 1
	})
	if noteinfo.maxCombo >= comboRange[4] then
		self.displayJudgement.comboLevel = "(S combo)"
	elseif noteinfo.maxCombo >= comboRange[3] then
		self.displayJudgement.comboLevel = "(A combo)"
	elseif noteinfo.maxCombo >= comboRange[2] then
		self.displayJudgement.comboLevel = "(B combo)"
	elseif noteinfo.maxCombo >= comboRange[1] then
		self.displayJudgement.comboLevel = "(C combo)"
	end
	-- create live graph
	local poly = {0, 128}
	for i = 1, 800 do
		local idx = (i-1) / 800 * #accuracyData
		local v0 = accuracyData[math.floor(idx)+1]
		local v1 = accuracyData[math.ceil(idx)+1] or accuracyData[#accuracyData]
		local t = idx % 1
		poly[#poly + 1] = i - 1
		poly[#poly + 1] = (1 - ((1 - t) * v0 + t * v1)) * 127
	end
	poly[#poly + 1] = 799
	poly[#poly + 1] = 128
	poly[#poly + 1] = 0
	poly[#poly + 1] = 128
	local meshCoords = love.math.triangulate(poly)
	local meshData = {}
	for i = 1, #meshCoords do
		local f = meshCoords[i]
		meshData[#meshData + 1] = {f[1], f[2], f[1]/128, f[2]/128}
		meshData[#meshData + 1] = {f[3], f[4], f[3]/128, f[4]/128}
		meshData[#meshData + 1] = {f[5], f[6], f[5]/128, f[6]/128}
	end
	self.images[2]:setWrap("repeat", "clamp")
	self.graphMesh = love.graphics.newMesh(meshData, "triangles", "static")
	self.graphMesh:setTexture(self.images[2])
end

function result:setReturnCallback(cb, opaque)
	self.returnButtonCallback = cb
	self.returnButtonOpaque = opaque
end

function result:setReplayCallback(cb, opaque)
	self.replayButtonCallback = cb
	self.replayButtonOpaque = opaque
end

function result:setSaveReplayCallback(cb, opaque)
	self.saveReplayButtonCallback = cb
	self.saveReplayButtonOpaque = opaque
end

return result
