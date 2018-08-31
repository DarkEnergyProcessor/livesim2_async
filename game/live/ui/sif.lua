-- Default SIF Live UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local lily = require("libs.lily")
local timer = require("libs.hump.timer")
local assetCache = require("asset_cache")
local async = require("async")
local color = require("color")
local uibase = require("game.live.uibase")
local sifui = Luaoop.class("livesim2.SIFLiveUI", uibase)

-- luacheck: no max line length

-----------------
-- Base system --
-----------------

local scoreAddTweenTarget = {{x = 570, scale = 1}, {opacity = 0}}

function sifui:__construct()
	-- as per uibase definition, constructor can use
	-- any asynchronous operation (async lib)
	local fontImageDataList = lily.loadMulti({
		{lily.newImageData, "assets/image/live/score_num/score.png"},
		{lily.newImageData, "assets/image/live/score_num/addscore.png"},
		{lily.newImageData, "assets/image/live/hp_num.png"}
	})
	self.timer = timer.new()
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
		"assets/image/live/ef_318_000.png",
		-- stamina
		"assets/image/live/live_gauge_02_01.png", -- 12
		"assets/image/live/live_gauge_02_02.png",
		"assets/image/live/live_gauge_02_03.png",
		"assets/image/live/live_gauge_02_04.png",
		"assets/image/live/live_gauge_02_05.png",
		"assets/image/live/live_gauge_02_06.png",
		-- effects
		"assets/image/live/circleeffect.png", -- 18
		"assets/image/live/ef_308.png",
		-- judgement
		"assets/image/live/ef_313_004_w2x.png", -- 20
		"assets/image/live/ef_313_003_w2x.png",
		"assets/image/live/ef_313_002_w2x.png",
		"assets/image/live/ef_313_001_w2x.png",
		"assets/image/live/ef_313_000_w2x.png",
		-- combo
		"assets/image/live/combo/1.png", -- 25
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
	self.scoreFont = love.graphics.newImageFont(fontImageDataList:getValues(1), "0123456789", -4)
	self.addScoreFont = love.graphics.newImageFont(fontImageDataList:getValues(2), "0123456789+", -5)
	self.staminaFont = love.graphics.newImageFont(fontImageDataList:getValues(3), "0123456789+-")
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
	-- variable setup
	self.opacity = 1
	self.textScaling = 1
	self.minimalEffect = false
	-- score variable setup
	self.currentScore = 0
	self.currentScoreAdd = 0 -- also as dirty flag
	self.currentScoreText = love.graphics.newText(self.scoreFont, "0")
	self.scoreBorders = {1, 2, 3, 4}
	self.scoreAddAnimationList = {}
	self.scoreFlashTimer = nil
	self.scoreFlashScale = 1
	self.scoreFlashOpacity = 1
	self.scoreBarFlashTimer = nil
	self.scoreBarFlashOpacity = 0
	self.scoreIsMax = false
	self.scoreBarImage = self.images[4]
	self.scoreBarQuad = love.graphics.newQuad(0, 0, 880, 38, 880, 38)
	self.scoreBarQuad:setViewport(0, 0, 42, 38)
	-- combo variable setup
	self.currentCombo = 0
	self.maxCombo = 0
	self.comboSpriteBatch = love.graphics.newSpriteBatch(self.images[25], 12, "stream")
	self.currentComboTextureIndex = 1
	self.comboNumberScale1 = 1.15
	self.comboNumberScale2 = 1.25
	self.comboNumberOpacity2 = 0.5
	self.comboNumberTimer = nil
	self.comboNumberTimer2 = nil
	-- SB pre-allocate (combo)
	for _ = 1, 12 do
		self.comboSpriteBatch:add(0, 0, 0, 0, 0)
	end
	-- judgement system variable setup
	self.judgementCenterPosition = {
		[self.images[20]] = {198, 38},
		[self.images[21]] = {147, 35},
		[self.images[22]] = {127, 35},
		[self.images[23]] = {86, 33},
		[self.images[24]] = {93, 30}
	}
	self.currentJudgement = self.images[20]
	self.judgementOpacity = 0
	self.judgementScale = 0
	self.judgementTimer = nil
	do
		local target = {judgementOpacity = 1, judgementScale = 1}
		local target2 = {judgementOpacity = 0}
		local showTimer, delayTimer, hideTimer
		self.judgementDelayFunc = function()
			showTimer = self.timer:tween(0.05, self, target, "out-sine")
			wait(0.17)
			self.judgementOpacity = 1
			hideTimer = self.timer:tween(0.2, self, target2)
			wait(0.2)
		end
		self.judgementResetTimer = function()
			if showTimer then
				self.timer:cancel(showTimer)
			end
			if delayTimer then
				self.timer:cancel(delayTimer)
			end
			if hideTimer then
				self.timer:cancel(hideTimer)
			end

			self.judgementOpacity = 0
			self.judgementScale = 0
		end
		local hideFunc = function()
			self.judgementOpacity = 1
			hideTimer = self.timer:tween(0.2, self, target2)
		end
		local delayFunc = function()
			delayTimer = self.timer:after(0.17, hideFunc)
		end
		self.judgementStartTimer = function()
			showTimer = self.timer:tween(0.05, self, target, "out-sine", delayFunc)
		end
	end
	-- pause system
	self.pauseEnabled = true
end

function sifui:update(dt)
	-- timer
	self.timer:update(dt)
	-- score effect
	if self.currentScoreAdd > 0 then
		if not(self.minimalEffect) then
			local emptyObj
			-- get unused one first
			for i = 1, #self.scoreAddAnimationList do
				local obj = self.scoreAddAnimationList[i]
				if obj.done then
					emptyObj = table.remove(self.scoreAddAnimationList, i)
					break
				end
			end

			if not(emptyObj) then
				-- create new one
				emptyObj = {
					timerHandle = nil,
					done = false,
					text = love.graphics.newText(self.addScoreFont),
					opacity = 1,
					scale = 1.125,
					x = 520,
				}
				emptyObj.func = function(wait)
					self.timer:tween(0.1, emptyObj, scoreAddTweenTarget[1])
					wait(0.2)
					self.timer:tween(0.2, emptyObj, scoreAddTweenTarget[2])
					wait(0.2)
					emptyObj.done = true
				end
			end

			-- set displayed text
			emptyObj.text:clear()
			emptyObj.text:add("+"..self.currentScoreAdd)
			-- start timer
			emptyObj.done = false
			emptyObj.opacity = 1
			emptyObj.scale = 1.125
			emptyObj.x = 520
			emptyObj.timerHandle = self.timer:script(emptyObj.func)
			-- insert
			self.scoreAddAnimationList[#self.scoreAddAnimationList + 1] = emptyObj
		end
		-- reset flag
		self.currentScoreAdd = 0
	end
	-- combo counter
	if self.currentCombo > 0 then
		-- set "combo" text
		self.comboSpriteBatch:setColor(color.compat(255, 255, 255, self.comboNumberOpacity2))
		self.comboSpriteBatch:set(2, self.comboQuad.combo, 61, -54, 0, self.comboNumberScale2, self.comboNumberScale2, 61, 17)
		self.comboSpriteBatch:setColor(color.white[1], color.white[2], color.white[3])
		self.comboSpriteBatch:set(1, self.comboQuad.combo, 61, -54, 0, self.comboNumberScale1, self.comboNumberScale1, 61, 17)
		-- set numbers
		local num = self.currentCombo
		local i = 3
		while num > 0 do
			self.comboSpriteBatch:set(
				i, self.comboQuad[num % 10],
				-29 - (i - 3) * 43, -53, 0,
				self.comboNumberScale1, self.comboNumberScale1, 24, 24
			)
			num = math.floor(num * 0.1)
			i = i + 1
		end
	end
	-- TODO: all things
end

--------------------
-- Scoring System --
--------------------

local flashTweenTarget = {scoreFlashScale = 1.6, scoreFlashOpacity = 0}
local barFlashTweenTarget = {scoreBarFlashOpacity = 0}

function sifui:setScoreRange(c, b, a, s)
	self.scoreBorders[1], self.scoreBorders[2], self.scoreBorders[3], self.scoreBorders[4] = c, b, a, s
end

function sifui:addScore(amount)
	amount = math.floor(amount)
	self.currentScore = self.currentScore + amount
	self.currentScoreAdd = self.currentScoreAdd + amount

	-- update text
	self.currentScoreText:clear()
	self.currentScoreText:add(tostring(self.currentScore))
	-- replay score flash
	if self.scoreFlashTimer then
		self.timer:cancel(self.scoreFlashTimer)
		self.scoreFlashScale = 1
		self.scoreFlashOpacity = 1
	end
	self.scoreFlashTimer = self.timer:tween(0.5, self, flashTweenTarget, "out-sine")
	-- update score quad
	if self.currentScore >= self.scoreBorders[4] and not(self.scoreIsMax) then
		-- S score
		self.scoreIsMax = true
		self.scoreBarImage = self.images[8]
		self.scoreBarQuad:setViewport(0, 0, 880, 38)
		-- add timer for S score flashing effect
		if self.scoreBarFlashTimer then
			self.timer:cancel(self.scoreBarFlashTimer)
		end
		self.scoreBarFlashTimer = self.timer:script(function(wait)
			local target = {scoreBarFlashOpacity = 0.5}
			while true do
				self.scoreBarFlashOpacity = 0.75
				self.timer:tween(1, self, target)
				wait(1)
			end
		end)
	elseif not(self.scoreIsMax) then
		local w
		-- calculate viewport width
		if self.currentScore >= self.scoreBorders[3] then
			-- A score
			w = 790 + math.floor((self.scoreBorders[3] - self.currentScore) / (self.scoreBorders[3] - self.scoreBorders[4]) * 84 + 0.5)
			self.scoreBarImage = self.images[7]
		elseif self.currentScore >= self.scoreBorders[2] then
			-- B score
			w = 665 + math.floor((self.scoreBorders[2] - self.currentScore) / (self.scoreBorders[2] - self.scoreBorders[3]) * 125 + 0.5)
			self.scoreBarImage = self.images[6]
		elseif self.currentScore >= self.scoreBorders[1] then
			-- C score
			w = 502 + math.floor((self.scoreBorders[1] - self.currentScore) / (self.scoreBorders[1] - self.scoreBorders[2]) * 163 + 0.5)
			self.scoreBarImage = self.images[5]
		else
			-- No score
			w = 42 + math.floor(self.currentScore / self.scoreBorders[1] * 460 + 0.5)
			self.scoreBarImage = self.images[4]
		end

		-- set quad viewport
		self.scoreBarQuad:setViewport(0, 0, w, 38)
		-- reset score bar flash effect (non-S score)
		if self.scoreBarFlashTimer then
			self.timer:cancel(self.scoreBarFlashTimer)
			self.scoreBarFlashOpacity = 1
		end
		self.scoreBarFlashTimer = self.timer:tween(0.5, self, barFlashTweenTarget)
	end
end

function sifui:getScore()
	return self.currentScore
end

------------------
-- Combo System --
------------------

local comboNumber1Target = {comboNumberScale1 = 1}
local comboNumber2Target = {comboNumberScale2 = 1.65, comboNumberOpacity2 = 0}

local function getComboNumberIndex(combo)
	if combo < 50 then
		-- 0-49
		return 1
	elseif combo < 100 then
		-- 50-99
		return 2
	elseif combo < 200 then
		-- 100-199
		return 3
	elseif combo < 300 then
		-- 200-299
		return 4
	elseif combo < 400 then
		-- 300-399
		return 5
	elseif combo < 500 then
		-- 400-499
		return 6
	elseif combo < 600 then
		-- 500-599
		return 7
	elseif combo < 1000 then
		-- 600-999
		return 8
	elseif combo < 2000 then
		-- 1000-1999
		return 9
	else
		-- >= 2000
		return 10
	end
end

function sifui:comboJudgement(judgement, addcombo)
	local breakCombo = false

	if judgement == "perfect" then
		self.currentJudgement = self.images[20]
	elseif judgement == "great" then
		self.currentJudgement = self.images[21]
	elseif judgement == "good" then
		self.currentJudgement = self.images[22]
		breakCombo = true
	elseif judgement == "bad" then
		self.currentJudgement = self.images[23]
		breakCombo = true
	elseif judgement == "miss" then
		self.currentJudgement = self.images[24]
		breakCombo = true
	else
		error("invalid judgement '"..judgement.."'", 2)
	end

	-- reset judgement animation
	self.judgementResetTimer()
	self.judgementStartTimer()

	if breakCombo then
		-- break combo
		-- clear all numbers in SB
		for i = 3, 12 do
			self.comboSpriteBatch:set(i, 0, 0, 0, 0, 0)
		end
		-- reset texture
		self.currentComboTextureIndex = 1
		self.comboSpriteBatch:setTexture(self.images[25])
	elseif addcombo then
		-- increment combo
		self.currentCombo = self.currentCombo + 1
		self.maxCombo = math.max(self.maxCombo, self.currentCombo)

		-- set combo texture when needed
		local idx = getComboNumberIndex(self.currentCombo)
		if self.currentComboTextureIndex ~= idx then
			self.comboSpriteBatch:setTexture(self.images[24 + idx])
			self.currentComboTextureIndex = idx
		end

		-- animate combo
		if self.comboNumberTimer then
			self.timer:cancel(self.comboNumberTimer)
			self.comboNumberScale1 = 1.15
		end
		if self.comboNumberTimer2 then
			self.timer:cancel(self.comboNumberTimer2)
			self.comboNumberScale2 = 1.25
			self.comboNumberOpacity2 = 0.5
		end
		self.comboNumberTimer = self.timer:tween(0.15, self, comboNumber1Target, "in-out-sine")
		self.comboNumberTimer = self.timer:tween(0.33, self, comboNumber2Target)
	end
end

function sifui:getCurrentCombo()
	return self.currentCombo
end

function sifui:getMaxCombo()
	return self.maxCombo
end

------------------
-- Pause button --
------------------

function sifui:enablePause()
	self.pauseEnabled = true
end

function sifui:disablePause()
	self.pauseEnabled = false
end

function sifui.checkPause(_, x, y)
	return x >= 898 and y >= -12 and x < 970 and y < 60
end

------------------
-- Other things --
------------------

function sifui:setOpacity(opacity)
	self.opacity = opacity
end

function sifui:setMinimalEffect(min)
	self.minimalEffect = min
end

-------------
-- Drawing --
-------------

function sifui:drawHeader()
	-- draw live header
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.images[1])
	love.graphics.draw(self.images[3], 5, 8, 0, 0.99545454, 0.86842105)
	-- score bar
	love.graphics.draw(self.scoreBarImage, self.scoreBarQuad, 5, 8, 0, 0.99545454, 0.86842105)
	if self.scoreIsMax then
		love.graphics.setColor(color.compat(255, 255, 255, self.scoreBarFlashOpacity * self.opacity))
		love.graphics.draw(self.images[11], 36, 3)
	elseif self.scoreBarFlashOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.scoreBarFlashOpacity * self.opacity))
		love.graphics.draw(self.images[9], 5, 8)
	end
	-- score number
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.currentScoreText, 476, 53, 0, 1, 1, self.currentScoreText:getWidth() * 0.5, 0)
	-- score flash
	if self.scoreBarFlashOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * self.scoreFlashOpacity))
		love.graphics.draw(self.images[10], 484, 72, 0, self.scoreFlashScale, self.scoreFlashScale, 159, 34)
	end
	-- score add effect
	for i = #self.scoreAddAnimationList, 1, -1 do
		local obj = self.scoreAddAnimationList[i]
		if obj.done then break end
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * obj.opacity))
		love.graphics.draw(obj.text, obj.x, 72, 0, obj.scale, obj.scale, 0, 16)
	end
end

function sifui:drawStatus()
	-- judgement
	if self.judgementOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.judgementOpacity * self.opacity))
		love.graphics.draw(
			self.currentJudgement, 480, 320, 0,
			self.judgementScale * self.textScaling,
			self.judgementScale * self.textScaling,
			self.judgementCenterPosition[self.currentJudgement][1],
			self.judgementCenterPosition[self.currentJudgement][2]
		)
	end
	-- combo
	if self.currentCombo > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
		love.graphics.draw(self.comboSpriteBatch, 480, 320 - 8 * (1 - self.textScaling), 0, self.textScaling)
	end
	-- TODO: tap effect
end

return sifui
