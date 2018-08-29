-- Default SIF Live UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local assetCache = require("asset_cache")
local lily = require("libs.lily")
local async = require("async")
local color = require("color")
local uibase = require("game.live.uibase")
local sifui = Luaoop.class("livesim2.SIFLiveUI", uibase)

function sifui:__construct()
	-- as per uibase definition, constructor can use
	-- any asynchronous operation (async lib)
	local fontImageDataList = lily.loadMulti({
		{lily.newImageData, "assets/image/live/score_num/score.png"},
		{lily.newImageData, "assets/image/live/score_num/addscore.png"},
		{lily.newImageData, "assets/image/live/hp_num.png"}
	})
	self.images = assetCache.loadMultipleImages({
		-- live header
		"assets/image/live/live_header.png", -- 1
		"assets/image/live/live_pause.png",
		-- score gauge
		"assets/image/live/live_gauge_03_02.png", -- 3
		"assets/image/live/live_gauge_03_03.png",
		"assets/image/live/live_gauge_03_04.png",
		"assets/image/live/live_gauge_03_05.png",
		"assets/image/live/live_gauge_03_06.png",
		"assets/image/live/live_gauge_03_07.png",
		"assets/image/live/l_gauge_17.png",
		-- scoring
		"assets/image/live/l_etc_46.png", -- 10
		-- stamina
		"assets/image/live/live_gauge_02_01.png", -- 11
		"assets/image/live/live_gauge_02_02.png",
		"assets/image/live/live_gauge_02_03.png",
		"assets/image/live/live_gauge_02_04.png",
		"assets/image/live/live_gauge_02_05.png",
		"assets/image/live/live_gauge_02_06.png",
		-- effects
		"assets/image/live/circleeffect.png", -- 17
		"assets/image/live/ef_308.png",
		-- judgement
		"assets/image/live/ef_313_004_w2x.png", -- 19
		"assets/image/live/ef_313_003_w2x.png",
		"assets/image/live/ef_313_002_w2x.png",
		"assets/image/live/ef_313_001_w2x.png",
		"assets/image/live/ef_313_000_w2x.png",
		-- combo
		"assets/image/live/combo/1.png", -- 24
		"assets/image/live/combo/2.png",
		"assets/image/live/combo/3.png",
		"assets/image/live/combo/4.png",
		"assets/image/live/combo/5.png",
		"assets/image/live/combo/6.png",
		"assets/image/live/combo/7.png",
		"assets/image/live/combo/8.png",
		"assets/image/live/combo/9.png",
		"assets/image/live/combo/10.png",
	}, {mipmaps = true})
	while fontImageDataList:isComplete() == false do
		async.wait()
	end
	-- fonts
	self.scoreFont = love.graphics.newImageFont(fontImageDataList:getValues(1), "0123456789")
	self.addScoreFont = love.graphics.newImageFont(fontImageDataList:getValues(2), "0123456789+")
	self.staminaFont = love.graphics.newImageFont(fontImageDataList:getValues(3), "0123456789")
	-- quads
	self.comboQuad = {
		[0] = love.graphics.newQuad(0, 0, 48, 48, 240, 130),
		love.graphics.newQuad(48, 0, 48, 48, 240, 130),
		love.graphics.newQuad(96, 0, 48, 48, 240, 130),
		love.graphics.newQuad(144, 0, 48, 48, 240, 130),
		love.graphics.newQuad(192, 0, 48, 48, 240, 130),
		love.graphics.newQuad(0, 48, 48, 48, 240, 130),
		love.graphics.newQuad(48, 48, 48, 48, 240, 130),
		love.graphics.newQuad(96, 48, 48, 48, 240, 130),
		love.graphics.newQuad(144, 48, 48, 48, 240, 130),
		love.graphics.newQuad(192, 48, 48, 48, 240, 130),
		combo = love.graphics.newQuad(0, 96, 123, 34, 240, 130)
	}
	-- misc
	self.opacity = 1
	self.currentScore = 0
	self.scoreBorders = {1, 2, 3, 4}
end

function sifui:update(dt)
	-- TODO
end

function sifui:drawHeader()
	-- draw live header
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.images[1])
	love.graphics.draw(self.images[3], 5, 8, 0, 0.99545454, 0.86842105)
end

return sifui
