-- Lovewing Live UI version 2 (SIF: Redefined)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local vector = require("libs.nvec")

local AssetCache = require("asset_cache")
local AudioManager = require("audio_manager")
local color = require("color")
local Util = require("util")

local UIBase = require("game.live.uibase")

---@class Livesim2.LovewingLiveUI: Livesim2.LiveUI
local LovewingUI = Luaoop.class("Livesim2.LovewingLiveUI", UIBase)

-----------------
-- Base system --
-----------------

local scoreColor = {
	[0] = {217, 62, 52}, -- warning color
	{253, 216, 53},    -- No score
	{0, 229, 255},      -- C score
	{255, 152, 0},     -- B score
	{255, 64, 129},    -- A score
	{224, 64, 251}     -- S score
}

local stageColor = {
	0x35, 0xe0, 0x5c,
	0xfc, 0xce, 0x4e,
	0x4e, 0x9f, 0xfc,
	0xff, 0x83, 0xbc,
	0xfc, 0x9f, 0x4e,
	0xfc, 0x4e, 0x4e -- Fail
}
local stageBadge = {
	love.graphics.newQuad(0, 0, 512, 128, 512, 256),
	love.graphics.newQuad(0, 128, 512, 128, 512, 256)
}
local stageIndexSuccess = {2, 6, 3, 1, 7}
local stageIndexFail = {4, 1, 5, 6}
local stageChars = {}
for i = 0, 6 do
	stageChars[i + 1] = love.graphics.newQuad(
		(i % 4) * 128,
		math.floor(i / 4) * 128,
		128, 128, 512, 320
	)
end
local stageCharsSmall = {}
for i = 0, 5 do
	stageCharsSmall[i + 1] = love.graphics.newQuad(
		(i % 8) * 64,
		math.floor(i / 8) * 64 + 256,
		64, 64, 512, 320
	)
end


function LovewingUI:__construct()
	self.timer = timer.new()
	self.fonts = AssetCache.loadMultipleFonts({
		{"fonts/Exo2-Regular.ttf", 12},
		{"fonts/Exo2-Regular.ttf", 16},
		{"fonts/Exo2-Regular.ttf", 43}
	})
	self.text = {
		combo = love.graphics.newText(self.fonts[1], "COMBO"),
		accuracy = love.graphics.newText(self.fonts[1], "ACC"),
		score = love.graphics.newText(self.fonts[3])
	}
	self.images = AssetCache.loadMultipleImages({
		"assets/image/live/lw2/Perfect.png",
		"assets/image/live/lw2/Great.png",
		"assets/image/live/lw2/Good.png",
		"assets/image/live/lw2/Meh.png",
		"assets/image/live/lw2/Miss.png",
		"assets/image/live/lw2/lw2_center.png",
		"assets/image/live/lw_pause.png",
		"assets/image/dummy.png",
		"assets/image/live/lw2/Untitled-4.png",
		"assets/image/live/lw2/perfect_badge_all.png"
	}, {mipmaps = true})
	self.imageCenter = {
		vector(self.images[1]:getDimensions()) * 0.5,
		vector(self.images[2]:getDimensions()) * 0.5,
		vector(self.images[3]:getDimensions()) * 0.5,
		vector(self.images[4]:getDimensions()) * 0.5,
		vector(self.images[5]:getDimensions()) * 0.5,
		vector(self.images[6]:getDimensions()) * 0.5,
		vector(self.images[7]:getDimensions()) * 0.5
	}
	self.stageData = {
		big = {
			-- success       , -- failure
			{139-320, 259, 0}, -- {209, 640, 0}
			{279-320, 259, 0}, -- {349, 640, 0}
			{419-320, 259, 0}, -- {489, 640, 0}
			{559-320, 259, 0}, -- {629, 640, 0}
			{699-320, 259, 0}, -- unused
		},
		small = 1,
		beat = math.huge,
		beat2 = math.huge,
		badgeDraw = false,
		badgeWhiteOpacity = 0,
		badgeWhiteScale = 0.5,
		badgeReal = false,
	}

	-- variable setup
	self.opacity = 1
	self.textScaling = 1
	self.noteIconTime = 0
	self.tapEffectList = {}
	self.pauseEnabled = true
	-- score
	self.currentScore = 0
	self.currentScoreDisplay = 0
	self.scoreBorders = {1, 2, 3, 4}
	self.scoreGlowColor = {scoreColor[1][1], scoreColor[1][2], scoreColor[1][3]}
	self.scoreGlowColorTween = nil
	self.scoreGlowPrev = 1
	self.scoreTimer = nil
	-- combo
	self.currentCombo = 0
	self.maxCombo = 0
	self.comboScale = 1
	self.comboText = love.graphics.newText(self.fonts[2])
	self.comboTimer = nil
	-- stamina
	self.maxStamina = 45
	self.stamina = 45
	self.staminaInterpolate = 45
	self.staminaTimer = nil
	self.staminaWarningDuration = 0
	self.staminaStencil = function()
		love.graphics.rectangle("fill", 18, 50, 924 * self.staminaInterpolate / self.maxStamina, 32)
	end
	-- Judgement
	self.currentJudgement = 5
	self.judgementOpacity = 0
	self.judgementScale = 0
	self.judgementTimer1 = nil
	self.judgementTimer2 = nil
	-- Accuracy
	self.accuracyCount = 0
	self.accuracy = 0

	-- live clear
	self.liveClearVoice = nil
	self.liveClearVoicePlayed = false
	self.liveClearTime = -math.huge -- 5 = live clear
	self.liveClearCallback = nil
	self.liveClearCallbackOpaque = nil
end

function LovewingUI:update(dt, paused)
	-- timer
	if not(paused) then
		self.timer:update(dt)

		if self.stageData.beat ~= math.huge then
			self.stageData.beat = (self.stageData.beat + dt) % 1
		end

		if self.stageData.beat2 ~= math.huge then
			self.stageData.beat2 = (self.stageData.beat2 + dt * 0.5) % 1
		end
	end

	local isWarn = self.staminaInterpolate / self.maxStamina < 0.3
	local warnMult = isWarn and 2 or 1
	self.staminaWarningDuration = Util.clamp(self.staminaWarningDuration + dt * (isWarn and 1 or -1), 0, 0.25)
	self.noteIconTime = (self.noteIconTime + dt * warnMult) % 1
	-- Score
	if self.currentScoreDisplay >= self.scoreBorders[4] and self.scoreGlowPrev == 4 then
		if self.scoreGlowColorTween then self.timer:cancel(self.scoreGlowColorTween) end
		self.scoreGlowColorTween = self.timer:tween(0.25, self.scoreGlowColor, scoreColor[5])
		self.scoreGlowPrev = 5
	elseif self.currentScoreDisplay >= self.scoreBorders[3] and self.scoreGlowPrev == 3 then
		if self.scoreGlowColorTween then self.timer:cancel(self.scoreGlowColorTween) end
		self.scoreGlowColorTween = self.timer:tween(0.25, self.scoreGlowColor, scoreColor[4])
		self.scoreGlowPrev = 4
	elseif self.currentScoreDisplay >= self.scoreBorders[2] and self.scoreGlowPrev == 2 then
		if self.scoreGlowColorTween then self.timer:cancel(self.scoreGlowColorTween) end
		self.scoreGlowColorTween = self.timer:tween(0.25, self.scoreGlowColor, scoreColor[3])
		self.scoreGlowPrev = 3
	elseif self.currentScoreDisplay >= self.scoreBorders[1] and self.scoreGlowPrev == 1 then
		if self.scoreGlowColorTween then self.timer:cancel(self.scoreGlowColorTween) end
		self.scoreGlowColorTween = self.timer:tween(0.25, self.scoreGlowColor, scoreColor[2])
		self.scoreGlowPrev = 2
	end

	-- live clear
	if self.liveClearTime ~= -math.huge then
		if self.liveClearTime > 0 then
			self.liveClearTime = self.liveClearTime - dt
		end

		if self.liveClearVoice and not(self.liveClearVoicePlayed) then
			AudioManager.play(self.liveClearVoice)
			self.liveClearVoicePlayed = true
		end

		if self.liveClearTime <= 0 and self.liveClearCallback then
			self.liveClearCallback(self.liveClearCallbackOpaque)
			self.liveClearCallback = nil
			self.liveClearCallbackOpaque = nil
		end
	end
end

function LovewingUI.getNoteSpawnPosition()
	return vector(480, 160)
end

function LovewingUI.getLanePosition()
	return {
		vector(816+64, 96+64 ),
		vector(785+64, 249+64),
		vector(698+64, 378+64),
		vector(569+64, 465+64),
		vector(416+64, 496+64),
		vector(262+64, 465+64),
		vector(133+64, 378+64),
		vector(46+64 , 249+64),
		vector(16+64 , 96+64 ),
	}
end

function LovewingUI:getFailAnimation()
	local t = {
		big = 640,
		bigOpacity = 0,
		small = 1,
		beat = math.huge,
		timer = timer.new()
	}

	-- time in ms
	t.timer:tween(500, t, {small = 0}, "out-cubic")
	t.timer:after(400, function()
		t.timer:tween(500, t, {big = 259}, "in-bounce")
		t.timer:tween(100, t, {bigOpacity = 1}, "out-cubic")
	end)
	t.beat = 0

	function t.update(_, dt)
		t.timer:update(dt)
		t.beat = (t.beat + dt * 0.001) % 1
	end

	function t.draw(_, x, y)
		love.graphics.push()
		love.graphics.translate(x - 480, y - 320)

		if t.small < 1 then
			local alpha = math.sqrt(1 - t.small)
			love.graphics.setColor(color.compat(255, 255, 255, alpha))
			love.graphics.circle("fill", 199, 220, 26)
			love.graphics.circle("fill", 265, 220, 26)
			love.graphics.circle("fill", 331, 220, 26)
			love.graphics.circle("fill", 397, 220, 26)
			love.graphics.circle("fill", 463, 220, 26)
			love.graphics.circle("line", 199, 220, 26)
			love.graphics.circle("line", 265, 220, 26)
			love.graphics.circle("line", 331, 220, 26)
			love.graphics.circle("line", 397, 220, 26)
			love.graphics.circle("line", 463, 220, 26)

			love.graphics.setColor(color.compat(stageColor[16], stageColor[17], stageColor[18], alpha))
			love.graphics.draw(self.images[9], stageCharsSmall[4], 199, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.draw(self.images[9], stageCharsSmall[5], 265, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.draw(self.images[9], stageCharsSmall[1], 331, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.draw(self.images[9], stageCharsSmall[3], 397, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.draw(self.images[9], stageCharsSmall[2], 463, 220, 0, 0.5, 0.5, 32, 32)
		end

		if t.beat ~= math.huge then
			local cubic = timer.tween["out-cubic"](math.min(t.beat * 1.5, 1))
			local sc = 1 + cubic * 0.5
			love.graphics.setColor(color.compat(255, 255, 255, 1 - cubic))
			love.graphics.circle("fill", 199, 220, 26 * sc)
			love.graphics.circle("fill", 265, 220, 26 * sc)
			love.graphics.circle("fill", 331, 220, 26 * sc)
			love.graphics.circle("fill", 397, 220, 26 * sc)
			love.graphics.circle("fill", 463, 220, 26 * sc)
			love.graphics.circle("line", 199, 220, 26 * sc)
			love.graphics.circle("line", 265, 220, 26 * sc)
			love.graphics.circle("line", 331, 220, 26 * sc)
			love.graphics.circle("line", 397, 220, 26 * sc)
			love.graphics.circle("line", 463, 220, 26 * sc)
		end

		if t.bigOpacity > 0 then
			local c1r, c1g, c1b, c1a = color.compat(255, 255, 255, t.bigOpacity)
			local c2r, c2g, c2b, c2a = color.compat(
				stageColor[16],
				stageColor[17],
				stageColor[18],
				t.bigOpacity
			)

			for i = 1, 4 do
				-- 130 = 69 + 61
				love.graphics.setColor(c1r, c1g, c1b, c1a)
				love.graphics.circle("fill", 130 + i * 140, t.big + 61, 61)
				love.graphics.setColor(c2r, c2g, c2b, c2a)
				love.graphics.circle("fill", 130 + i * 140, t.big + 61, 56)
				love.graphics.setColor(c1r, c1g, c1b, c1a)
				love.graphics.circle("line", 130 + i * 140, t.big + 61, 61)
				love.graphics.setColor(c2r, c2g, c2b, c2a)
				love.graphics.circle("line", 130 + i * 140, t.big + 61, 56)
			end

			love.graphics.setColor(c1r, c1g, c1b, c1a)
			for i = 1, 4 do
				love.graphics.draw(
					self.images[9], stageChars[stageIndexFail[i]],
					130 + i * 140, t.big + 61,
					0, 0.5, 0.5, 64, 64
				)
			end
		end

		love.graphics.pop()
	end

	return t
end

--------------------
-- Scoring System --
--------------------

function LovewingUI:setScoreRange(c, b, a, s)
	self.scoreBorders[1], self.scoreBorders[2], self.scoreBorders[3], self.scoreBorders[4] = c, b, a, s
end

function LovewingUI:addScore(amount)
	self.currentScore = self.currentScore + math.floor(amount)

	if self.scoreTimer then
		self.timer:cancel(self.scoreTimer)
		self.scoreTimer = nil
	end

	self.scoreTimer = self.timer:tween(0.3, self, {
		currentScoreDisplay = self.currentScore,
	}, "out-quart")
end

function LovewingUI:getScore()
	return self.currentScore
end

------------------
-- Combo System --
------------------

function LovewingUI:comboJudgement(judgement, addcombo)
	local breakCombo = false

	self.accuracyCount = self.accuracyCount + 1
	if judgement == "perfect" then
		self.currentJudgement = 1
		self.accuracy = self.accuracy + 1
	elseif judgement == "great" then
		self.currentJudgement = 2
		self.accuracy = self.accuracy + 0.88
	elseif judgement == "good" then
		self.currentJudgement = 3
		self.accuracy = self.accuracy + 0.8
		breakCombo = true
	elseif judgement == "bad" then
		self.currentJudgement = 4
		self.accuracy = self.accuracy + 0.4
		breakCombo = true
	elseif judgement == "miss" then
		self.currentJudgement = 5
		breakCombo = true
	else
		error("invalid judgement '"..tostring(judgement).."'", 2)
	end

	-- combo things
	if breakCombo then
		self.currentCombo = 0
	elseif addcombo then
		self.currentCombo = self.currentCombo + 1
		self.maxCombo = math.max(self.maxCombo, self.currentCombo)

		if self.comboTimer then
			self.timer:cancel(self.comboTimer)
			self.comboTimer = nil
		end
		self.comboScale = 1.25
		self.comboTimer = self.timer:tween(0.25, self, {comboScale = 1}, "out-sine")
	end

	-- judgement things
	if self.judgementTimer1 then
		self.timer:cancel(self.judgementTimer1)
		self.judgementTimer1 = nil
	end

	if self.judgementTimer2 then
		self.timer:cancel(self.judgementTimer2)
		self.judgementTimer2 = nil
	end

	self.judgementScale = 0
	self.judgementOpacity = 1
	self.judgementTimer1 = self.timer:tween(0.4, self, {judgementScale = 1}, "out-expo")
	self.judgementTimer2 = self.timer:tween(1, self, {judgementOpacity = 0}, "in-quad")
end

function LovewingUI:getCurrentCombo()
	return self.currentCombo
end

function LovewingUI:getMaxCombo()
	return self.maxCombo
end

function LovewingUI:getScoreComboMultipler()
	if self.currentCombo < 50 then
		return 1
	elseif self.currentCombo < 100 then
		return 1.1
	elseif self.currentCombo < 200 then
		return 1.15
	elseif self.currentCombo < 400 then
		return 1.2
	elseif self.currentCombo < 600 then
		return 1.25
	elseif self.currentCombo < 800 then
		return 1.3
	else
		return 1.35
	end
end

-------------
-- Stamina --
-------------

function LovewingUI:setMaxStamina(val)
	self.maxStamina = math.min(assert(val > 0 and val, "invalid value"), 99)
	self.stamina = self.maxStamina
	self.staminaInterpolate = self.stamina
end

function LovewingUI:getMaxStamina()
	return self.maxStamina
end

function LovewingUI:getStamina()
	return self.stamina
end

function LovewingUI:addStamina(val)
	val = math.floor(val)
	if val == 0 then return end

	self.stamina = Util.clamp(self.stamina + val, 0, self.maxStamina)

	if self.staminaTimer then
		self.timer:cancel(self.staminaTimer)
		self.staminaTimer = nil
	end

	self.staminaTimer = self.timer:tween(0.5, self, {staminaInterpolate = self.stamina}, "out-quart")
end

------------------
-- Pause button --
------------------

function LovewingUI:enablePause()
	self.pauseEnabled = true
end

function LovewingUI:disablePause()
	self.pauseEnabled = false
end

function LovewingUI:isPauseEnabled()
	return self.pauseEnabled
end

function LovewingUI:checkPause(x, y)
	return self:isPauseEnabled() and x >= 34 and y >= 17 and x < 63 and y < 46
end

------------------
-- Other things --
------------------

function LovewingUI:addTapEffect(x, y, r, g, b, a)
	local tap
	for i = 1, #self.tapEffectList do
		local w = self.tapEffectList[i]
		if w.done then
			tap = table.remove(self.tapEffectList, i)
			break
		end
	end

	if not(tap) then
		tap = {
			x = 0, y = 0, r = 255, g = 255, b = 255, a = 1,
			opacity = 1, scale = 0,
			done = false
		}
		tap.func = function()
			tap.done = true
		end
	end

	tap.x, tap.y, tap.r, tap.g, tap.b, tap.a = x, y, r, g, b, a
	tap.opacity = 1
	tap.scale = 1
	tap.done = false
	self.timer:tween(0.3, tap, {scale = 2}, "out-cubic", tap.func)
	self.timer:tween(0.3, tap, {opacity = 0})

	self.tapEffectList[#self.tapEffectList + 1] = tap
end

function LovewingUI:setTextScaling(scale)
	self.textScaling = scale
end

function LovewingUI:getOpacity()
	return self.opacity
end

function LovewingUI:setOpacity(opacity)
	self.opacity = opacity
	self.fullComboAnim:setOpacity(opacity * 255)
	self.liveClearAnim:setOpacity(opacity * 255)
end

function LovewingUI.setComboCheer()
end

function LovewingUI.setTotalNotes()
end

function LovewingUI:startLiveClearAnimation(fullcombo, callback, opaque)
	if self.liveClearTime == -math.huge then
		self.pauseEnabled = false
		self.liveClearTime = 5
		self.liveClearCallback = callback
		self.liveClearCallbackOpaque = opaque

		self.timer:tween(0.5, self.stageData, {small = 0}, "out-cubic")
		self.stageData.beat = 0

		for i = 1, 5 do
			self.timer:after((6 - i) * 0.1 + 0.3, function()
				self.timer:tween(0.3, self.stageData.big[i], {-1 + i * 140, 259, 1}, "out-cubic")
			end)
		end

		self.timer:after(2, function()
			self.stageData.beat2 = 0
		end)

		if fullcombo then
			self.timer:after(1, function()
				self.stageData.badgeDraw = true

				self.timer:tween(0.5, self.stageData, {badgeWhiteOpacity = 1}, "out-quad")
				self.timer:after(0.5, function()
					self.stageData.badgeReal = true
					self.timer:tween(0.5, self.stageData, {badgeWhiteScale = 0.75, badgeWhiteOpacity = 0}, "out-quad")
				end)
			end)
		end
	end
end

function LovewingUI:setLiveClearVoice(voice)
	self.liveClearVoice = voice
end

-------------
-- Drawing --
-------------

local function setColor(warn, r, g, b, a)
	local warnLerp = warn / 0.25
	local c1, c2, c3, c4

	if type(r) == "table" then
		c1 = Util.lerp(r[1], 217, warnLerp)
		c2 = Util.lerp(r[2], 62, warnLerp)
		c3 = Util.lerp(r[3], 52, warnLerp)
		c4 = Util.lerp(r[4] or g or 255, a or 255, warnLerp)
	else
		c1 = Util.lerp(r, 217, warnLerp)
		c2 = Util.lerp(g, 62, warnLerp)
		c3 = Util.lerp(b, 52, warnLerp)
		c4 = a
	end

	love.graphics.setColor(color.compat(c1, c2, c3, c4))
end

function LovewingUI:drawHeader()
	-- Placement
	setColor(self.staminaWarningDuration, 255, 190, 63, self.opacity)
	love.graphics.rectangle("fill", 190, 21, 140, 24, 4, 4)
	love.graphics.rectangle("line", 190, 21, 140, 24, 4, 4)
	setColor(self.staminaWarningDuration, 249, 141, 81, self.opacity)
	love.graphics.rectangle("fill", 630, 21, 140, 24, 4, 4)
	love.graphics.rectangle("line", 630, 21, 140, 24, 4, 4)

	-- Stamina bar
	local lz = love.graphics.getLineWidth()
	Util.stencil11(self.staminaStencil, "increment", 1)
	Util.setStencilTest11("greater", 0)
	setColor(self.staminaWarningDuration, self.scoreGlowColor, self.opacity)
	love.graphics.rectangle("fill", 16, 60, 928, 16, 8, 8)
	Util.setStencilTest11()
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 18, 60, 924, 18, 10, 10)
	love.graphics.setLineWidth(lz)

	-- Text
	local shader = love.graphics.getShader()
	love.graphics.setShader(Util.drawText.workaroundShader)
	love.graphics.setFont(self.fonts[2])
	love.graphics.draw(self.text.combo, 197, 26)
	love.graphics.draw(self.text.accuracy, 636, 26)
	do
		-- Combo
		local str = tostring(self.currentCombo)
		local w = self.fonts[2]:getWidth(str) * 0.5
		love.graphics.print(str, 322 - w, 31, 0, self.comboScale, self.comboScale, w, 8)
		-- Accuracy
		str = string.format("%.2f%%", self.accuracyCount == 0 and 0 or (self.accuracy / self.accuracyCount * 100))
		w = self.fonts[2]:getWidth(str) * 0.5
		love.graphics.print(str, 763 - w, 31, 0, 1, 1, w, 8)
		-- Score
		love.graphics.setFont(self.fonts[3])
		str = tostring(math.floor(self.currentScoreDisplay))
		w = self.fonts[3]:getWidth(str) * 0.5
		setColor(self.staminaWarningDuration, self.scoreGlowColor, self.opacity)
		love.graphics.print(str, 480, 7, 0, 1, 1, w, 0)
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
		love.graphics.print(str, 480, 5, 0, 1, 1, w, 0)
	end

	-- Pause
	if self.pauseEnabled then
		love.graphics.draw(self.images[7], 38, 21, 0, 0.19, 0.19)
	end
	love.graphics.setShader(shader)
end

function LovewingUI:drawStatus()
	-- Tap effect
	for i = #self.tapEffectList, 1, -1 do
		local tap = self.tapEffectList[i]
		if tap.done then break end

		love.graphics.setColor(color.compat(tap.r, tap.g, tap.b, tap.a * tap.opacity * self.opacity))
		love.graphics.draw(self.images[8], tap.x, tap.y, 0, tap.scale, tap.scale, 64, 64)
	end

	-- Judgement
	if self.judgementOpacity > 0 then
		local i = self.imageCenter[self.currentJudgement]
		local s = self.judgementScale * self.textScaling * 0.4
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * self.judgementOpacity * 0.75))
		love.graphics.draw(self.images[self.currentJudgement], 480, 370, 0, s, s, i:unpack())
	end

	-- Musical icon
	local lz = love.graphics.getLineWidth()
	local interp = self.noteIconTime * self.noteIconTime
	local nicScale = 0.6 + 0.15 * math.abs(2 * self.noteIconTime - 1)
	setColor(self.staminaWarningDuration, self.scoreGlowColor, self.opacity)
	love.graphics.circle("fill", 480, 160, 51)
	love.graphics.circle("line", 480, 160, 51)
	setColor(self.staminaWarningDuration, self.scoreGlowColor, self.opacity * (1 - interp))
	love.graphics.setLineWidth(7)
	love.graphics.circle("line", 480, 160, 46 + interp * 30)
	love.graphics.setLineWidth(lz)
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity * (1 - interp)))
	love.graphics.draw(self.images[6], 480, 160, 0, 0.75, 0.75, self.imageCenter[6]:unpack())
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.images[6], 480, 160, 0, nicScale, nicScale, self.imageCenter[6]:unpack())

	-- Live clear
	if self.liveClearTime ~= -math.huge then

		if self.stageData.small < 1 then
			local alpha = math.sqrt(1 - self.stageData.small)

			-- draw black overlay
			love.graphics.setColor(color.compat(0, 0, 0, (1 - self.stageData.small) * 0.25))
			love.graphics.rectangle("fill", -88, -43, 1136, 726)

			love.graphics.setColor(color.compat(255, 255, 255, alpha))
			love.graphics.circle("fill", 199, 220, 26)
			love.graphics.circle("fill", 265, 220, 26)
			love.graphics.circle("fill", 331, 220, 26)
			love.graphics.circle("fill", 397, 220, 26)
			love.graphics.circle("fill", 463, 220, 26)
			love.graphics.circle("line", 199, 220, 26)
			love.graphics.circle("line", 265, 220, 26)
			love.graphics.circle("line", 331, 220, 26)
			love.graphics.circle("line", 397, 220, 26)
			love.graphics.circle("line", 463, 220, 26)

			love.graphics.setColor(color.compat(stageColor[1], stageColor[2], stageColor[3], alpha))
			love.graphics.draw(self.images[9], stageCharsSmall[4], 199, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.setColor(color.compat(stageColor[4], stageColor[5], stageColor[6], alpha))
			love.graphics.draw(self.images[9], stageCharsSmall[5], 265, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.setColor(color.compat(stageColor[7], stageColor[8], stageColor[9], alpha))
			love.graphics.draw(self.images[9], stageCharsSmall[1], 331, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.setColor(color.compat(stageColor[10], stageColor[11], stageColor[12], alpha))
			love.graphics.draw(self.images[9], stageCharsSmall[3], 397, 220, 0, 0.5, 0.5, 32, 32)
			love.graphics.setColor(color.compat(stageColor[13], stageColor[14], stageColor[15], alpha))
			love.graphics.draw(self.images[9], stageCharsSmall[2], 463, 220, 0, 0.5, 0.5, 32, 32)
		end

		if self.stageData.beat ~= math.huge then
			local cubic = timer.tween["out-cubic"](math.min(self.stageData.beat * 1.5, 1))
			local sc = 1 + cubic * 0.5
			love.graphics.setColor(color.compat(255, 255, 255, 1 - cubic))
			love.graphics.circle("fill", 199, 220, 26 * sc)
			love.graphics.circle("fill", 265, 220, 26 * sc)
			love.graphics.circle("fill", 331, 220, 26 * sc)
			love.graphics.circle("fill", 397, 220, 26 * sc)
			love.graphics.circle("fill", 463, 220, 26 * sc)
			love.graphics.circle("line", 199, 220, 26 * sc)
			love.graphics.circle("line", 265, 220, 26 * sc)
			love.graphics.circle("line", 331, 220, 26 * sc)
			love.graphics.circle("line", 397, 220, 26 * sc)
			love.graphics.circle("line", 463, 220, 26 * sc)
		end

		for i = 1, 5 do
			local item = self.stageData.big[i]
			if item[3] > 0 then
				local c1r, c1g, c1b, c1a = color.compat(255, 255, 255, item[3])
				local c2r, c2g, c2b, c2a = color.compat(
					stageColor[3 * i - 2],
					stageColor[3 * i - 1],
					stageColor[3 * i - 0],
					item[3]
				)

				love.graphics.setColor(c1r, c1g, c1b, c1a)
				love.graphics.circle("fill", item[1] + 61, item[2] + 61, 61)
				love.graphics.setColor(c2r, c2g, c2b, c2a)
				love.graphics.circle("fill", item[1] + 61, item[2] + 61, 56)
				love.graphics.setColor(c1r, c1g, c1b, c1a)
				love.graphics.circle("line", item[1] + 61, item[2] + 61, 61)
				love.graphics.setColor(c2r, c2g, c2b, c2a)
				love.graphics.circle("line", item[1] + 61, item[2] + 61, 56)
			end
		end

		for i = 1, 5 do
			local item = self.stageData.big[i]
			if item[3] > 0 then
				local c1r, c1g, c1b, c1a = color.compat(255, 255, 255, item[3])

				love.graphics.setColor(c1r, c1g, c1b, c1a)
				love.graphics.draw(
					self.images[9], stageChars[stageIndexSuccess[i]],
					item[1] + 61, item[2] + 61,
					0, 0.5, 0.5, 64, 64
				)
			end
		end

		if self.stageData.beat2 ~= math.huge then
			local cubic = timer.tween["out-cubic"](math.min(self.stageData.beat2 * 2, 1))
			local sc = 1 + cubic * 0.2
			love.graphics.setColor(color.compat(255, 255, 255, 1 - cubic))

			for i = 1, 5 do
				local item = self.stageData.big[i]
				love.graphics.circle("fill", item[1] + 61, item[2] + 61, 61 * sc)
			end

			for i = 1, 5 do
				local item = self.stageData.big[i]
				love.graphics.circle("line", item[1] + 61, item[2] + 61, 61 * sc)
			end
		end

		if self.stageData.badgeDraw then
			local rot = math.rad(-20)

			if self.stageData.badgeReal then
				love.graphics.setColor(color.white)
				love.graphics.draw(self.images[10], stageBadge[2], 780, 378, rot, 0.5, 0.5, 256, 64)
				love.graphics.setColor(
					color.compat(255, 255, 255, math.max(-math.abs(self.stageData.beat - 0.25) + 0.25, 0))
				)
				love.graphics.draw(self.images[10], stageBadge[1], 780, 378, rot, 0.5, 0.5, 256, 64)
			end

			love.graphics.setColor(color.compat(255, 255, 255, self.stageData.badgeWhiteOpacity))
			love.graphics.draw(
				self.images[10], stageBadge[1],
				780, 378, rot,
				self.stageData.badgeWhiteScale,
				self.stageData.badgeWhiteScale,
				256, 64
			)
		end
	end
end

return LovewingUI
