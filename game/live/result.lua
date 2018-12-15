-- Result screen
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")

local assetCache = require("asset_cache")
local mainFont = require("font")
local color = require("color")
local util = require("util")
local L = require("language")

local glow = require("game.afterglow")
local longButtonUI = require("game.ui.long_button")
local selectButtonUI = require("game.ui.select_button")

local result = Luaoop.class("livesim2.Result")

local function addTextShadowRight(text, str, x, y, w, intensity)
	x = x or 0 y = y or 0
	intensity = intensity or 1
	text:addf({color.black, str}, w, "right", x-intensity, y-intensity)
	text:addf({color.black, str}, w, "right", x+intensity, y+intensity)
	text:addf({color.white, str}, w, "right", x, y)
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
	self.fonts = {mainFont.get(26, 30, 40)}
	self.tokenQuad = love.graphics.newQuad(14 * 128, 15 * 128, 128, 128, 2048, 2048)
	-- frame
	self.frame = glow.frame(0, 0, 960, 640)
	self.frameAdded = false
	-- timer
	self.timer = timer.new()
	-- live graph mesh
	self.graphMesh = nil
	-- return button
	self.returnButtonCallback = nil
	self.returnButtonOpaque = nil
	self.returnRetryTimer = -math.huge
	self.returnButton = longButtonUI(L"livesim2:result:returnHoldRetry")
	self.returnButton:addEventListener("mousereleased", function()
		if self.returnRetryTimer ~= -math.huge then
			self.returnButtonCallback(self.returnButtonOpaque, false)
		end
		self.returnRetryTimer = -math.huge
	end)
	self.returnButton:addEventListener("mousecanceled", function()
		self.returnRetryTimer = -math.huge
	end)
	self.returnButton:addEventListener("mousepressed", function()
		self.returnRetryTimer = 0
	end)
	self.frame:addElement(self.returnButton, 101, 556)
	-- replay button
	self.replayButtonCallback = nil
	self.replayButtonOpaque = nil
	self.replayButton = selectButtonUI(L"livesim2:result:replay")
	self.replayButton:addEventListener("mousereleased", function()
		return self.replayButtonCallback(self.replayButtonOpaque)
	end)
	self.frame:addElement(self.replayButton, 600, 314)
	-- save replay button
	self.saveReplayVanishTimer = 0
	self.saveReplayButtonCallback = nil
	self.saveReplayButtonOpaque = nil
	self.saveReplayButton = selectButtonUI(L"livesim2:result:saveReplay")
	self.saveReplayButton:addEventListener("mousereleased", function()
		-- must return status message
		self.saveReplayStatus = tostring(self.saveReplayButtonCallback(self.saveReplayButtonOpaque))
		self.saveReplayVanishTimer = 1
	end)
	self.frame:addElement(self.saveReplayButton, 600, 356)
	-- text objects
	self.staticText = love.graphics.newText(self.fonts[3])
	util.addTextWithShadow(self.staticText, L"general:maxCombo", 600, 80)
	util.addTextWithShadow(self.staticText, L"general:token", 648, 156)
	util.addTextWithShadow(self.staticText, L"general:score", 600, 232)
	self.beatmapNameText = love.graphics.newText(self.fonts[1])
	util.addTextWithShadow(self.beatmapNameText, beatmapName, 0, 0)
	self.statusText = love.graphics.newText(self.fonts[2])
	self.judgementText = love.graphics.newText(self.fonts[3])
	-- information table
	self.noteInfoTable = nil
	self.displayJudgement = {
		perfect = 0, perfectPercentage = 0,
		great = 0, greatPercentage = 0,
		good = 0, goodPercentage = 0,
		bad = 0, badPercentage = 0,
		miss = 0, missPercentage = 0,
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
	if not(self.frameAdded) then
		glow.addFrame(self.frame)
		self.frameAdded = true
	end

	self.timer:update(dt)
	self.saveReplayVanishTimer = self.saveReplayVanishTimer - dt
	self.returnRetryTimer = self.returnRetryTimer + dt

	if self.returnRetryTimer >= 1 then
		self.returnRetryTimer = -math.huge
		self.returnButtonCallback(self.returnButtonOpaque, true)
	end

	if self.noteInfoTable then
		-- some little animation
		-- left side
		self.judgementText:clear()
		util.addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.perfect)), 388, 80)
		util.addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.great)), 388, 144)
		util.addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.good)), 388, 208)
		util.addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.bad)), 388, 272)
		util.addTextWithShadow(self.judgementText, tostring(math.floor(self.displayJudgement.miss)), 388, 336)
		addTextShadowRight(self.judgementText, string.format("%.2f%%", self.displayJudgement.perfectPercentage), 0, 80, 160)
		addTextShadowRight(self.judgementText, string.format("%.2f%%", self.displayJudgement.greatPercentage), 0, 144, 160)
		addTextShadowRight(self.judgementText, string.format("%.2f%%", self.displayJudgement.goodPercentage), 0, 208, 160)
		addTextShadowRight(self.judgementText, string.format("%.2f%%", self.displayJudgement.badPercentage), 0, 272, 160)
		addTextShadowRight(self.judgementText, string.format("%.2f%%", self.displayJudgement.missPercentage), 0, 336, 160)
		-- right side
		self.statusText:clear()
		local comboStatus = self.displayJudgement.value == 1 and self.displayJudgement.comboLevel or ""
		util.addTextWithShadow(
			self.statusText,
			string.format("%d/%d %s", self.displayJudgement.combo, self.displayJudgement.maxCombo, comboStatus),
			600, 118
		)
		util.addTextWithShadow(
			self.statusText,
			string.format("%d/%d", self.displayJudgement.token, self.displayJudgement.maxToken),
			600, 198
		)
		util.addTextWithShadow(
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
	love.graphics.draw(self.images[4], 225, 80, 0, 0.5, 0.5)
	love.graphics.draw(self.images[5], 251, 144, 0, 0.5, 0.5)
	love.graphics.draw(self.images[6], 261, 208, 0, 0.5, 0.5)
	love.graphics.draw(self.images[7], 281, 272, 0, 0.5, 0.5)
	love.graphics.draw(self.images[8], 278, 336, 0, 0.5, 0.5)
	-- token image
	love.graphics.draw(self.images[1], self.tokenQuad, 600, 156, 0, 0.3, 0.3)
	-- live graph
	if self.graphMesh then
		love.graphics.draw(self.graphMesh, 80, 422)
	end
	-- draw text
	love.graphics.draw(self.staticText)
	love.graphics.draw(self.statusText)
	love.graphics.draw(self.judgementText, 48, 0)
	love.graphics.draw(self.beatmapNameText, 80, 390)
	if self.saveReplayVanishTimer > 0 then
		love.graphics.setFont(self.fonts[1])
		love.graphics.setColor(color.black)
		love.graphics.print(self.saveReplayStatus, 599, 389)
		love.graphics.print(self.saveReplayStatus, 601, 391)
		love.graphics.setColor(color.white)
		love.graphics.print(self.saveReplayStatus, 600, 390)
	end

	-- draw buttons (gui)
	if self.frameAdded then
		self.frame:draw()
	end
end

function result:setInformation(noteinfo, accuracyData, comboRange)
	-- see self.persist.noteInfo in game/states/livesim2.lua
	local weightSum = noteinfo.perfect + noteinfo.great + noteinfo.good + noteinfo.bad + noteinfo.miss
	self.noteInfoTable = noteinfo
	self.displayJudgement.combo = noteinfo.maxCombo
	self.displayJudgement.maxCombo = noteinfo.totalNotes
	self.displayJudgement.maxToken = noteinfo.tokenAmount
	self.timer:tween(1, self.displayJudgement, {
		perfect = noteinfo.perfect,
		perfectPercentage = util.round(100 * noteinfo.perfect / weightSum, 2),
		great = noteinfo.great,
		greatPercentage = util.round(100 * noteinfo.great / weightSum, 2),
		good = noteinfo.good,
		goodPercentage = util.round(100 * noteinfo.good / weightSum, 2),
		bad = noteinfo.bad,
		badPercentage = util.round(100 * noteinfo.bad / weightSum, 2),
		miss = noteinfo.miss,
		missPercentage = util.round(100 * noteinfo.miss / weightSum, 2),
		token = noteinfo.token,
		combo = noteinfo.combo,
		score = noteinfo.score,
		value = 1
	})
	if noteinfo.maxCombo >= comboRange[4] then
		self.displayJudgement.comboLevel = L("livesim2:result:comboRange", {range="S"})
	elseif noteinfo.maxCombo >= comboRange[3] then
		self.displayJudgement.comboLevel = L("livesim2:result:comboRange", {range="A"})
	elseif noteinfo.maxCombo >= comboRange[2] then
		self.displayJudgement.comboLevel = L("livesim2:result:comboRange", {range="B"})
	elseif noteinfo.maxCombo >= comboRange[1] then
		self.displayJudgement.comboLevel = L("livesim2:result:comboRange", {range="C"})
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
