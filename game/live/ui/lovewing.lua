-- Lovewing Live UI version 2 (SIF: Redefined)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Yohane = require("libs.Yohane")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local vector = require("libs.nvec")

local assetCache = require("asset_cache")
local audioManager = require("audio_manager")
local cache = require("cache")
local color = require("color")
local util = require("util")

local uibase = require("game.live.uibase")

local lwui = Luaoop.class("livesim2.LovewingLiveUI", uibase)

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

function lwui:__construct()
	self.timer = timer.new()
	self.fonts = assetCache.loadMultipleFonts({
		{"fonts/Exo2-Regular.ttf", 12},
		{"fonts/Exo2-Regular.ttf", 16},
		{"fonts/Exo2-Regular.ttf", 43}
	})
	self.text = {
		combo = love.graphics.newText(self.fonts[1], "COMBO"),
		accuracy = love.graphics.newText(self.fonts[1], "ACC"),
		score = love.graphics.newText(self.fonts[3])
	}
	self.images = assetCache.loadMultipleImages({
		"assets/image/live/lw2/Perfect.png",
		"assets/image/live/lw2/Great.png",
		"assets/image/live/lw2/Good.png",
		"assets/image/live/lw2/Meh.png",
		"assets/image/live/lw2/Miss.png",
		"assets/image/live/lw2/lw2_center.png",
		"assets/image/live/lw_pause.png",
		"assets/image/dummy.png"
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
	self.fullComboAnim = cache.get("live_fullcombo")
	if not(self.fullComboAnim) then
		self.fullComboAnim = Yohane.newFlashFromFilename("flash/live_fullcombo.flsh")
		cache.set("live_fullcombo", self.fullComboAnim)
	end
	self.liveClearAnim = cache.get("live_clear")
	if not(self.liveClearAnim) then
		self.liveClearAnim = Yohane.newFlashFromFilename("flash/live_clear.flsh")
		cache.set("live_clear", self.liveClearAnim)
	end
	self.fullComboAnim = self.fullComboAnim:clone()
	self.liveClearAnim = self.liveClearAnim:clone()
	self.liveClearTime = -math.huge -- 7 = FC + live clear; 5 = live clear only
	self.liveClearCallback = nil
	self.liveClearCallbackOpaque = nil
	self.fullComboAnim:setMovie("ef_329")
	self.liveClearAnim:setMovie("ef_311")
end

function lwui:update(dt, paused)
	-- timer
	if not(paused) then
		self.timer:update(dt)
	end

	local isWarn = self.staminaInterpolate / self.maxStamina < 0.3
	local warnMult = isWarn and 2 or 1
	self.staminaWarningDuration = util.clamp(self.staminaWarningDuration + dt * (isWarn and 1 or -1), 0, 0.25)
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
		local flash = self.liveClearTime > 5 and self.fullComboAnim or self.liveClearAnim
		if self.liveClearVoice and not(self.liveClearVoicePlayed) and flash == self.liveClearAnim then
			audioManager.play(self.liveClearVoice)
			self.liveClearVoicePlayed = true
		end
		flash:update(dt * 1000)

		if self.liveClearTime <= 0 and self.liveClearCallback then
			self.liveClearCallback(self.liveClearCallbackOpaque)
			self.liveClearCallback = nil
			self.liveClearCallbackOpaque = nil
		end
	end
end

function lwui.getNoteSpawnPosition()
	return vector(480, 160)
end

function lwui.getLanePosition()
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

--------------------
-- Scoring System --
--------------------

function lwui:setScoreRange(c, b, a, s)
	self.scoreBorders[1], self.scoreBorders[2], self.scoreBorders[3], self.scoreBorders[4] = c, b, a, s
end

function lwui:addScore(amount)
	self.currentScore = self.currentScore + math.floor(amount)

	if self.scoreTimer then
		self.timer:cancel(self.scoreTimer)
		self.scoreTimer = nil
	end

	self.scoreTimer = self.timer:tween(0.3, self, {
		currentScoreDisplay = self.currentScore,
	}, "out-quart")
end

function lwui:getScore()
	return self.currentScore
end

------------------
-- Combo System --
------------------

function lwui:comboJudgement(judgement, addcombo)
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

function lwui:getCurrentCombo()
	return self.currentCombo
end

function lwui:getMaxCombo()
	return self.maxCombo
end

function lwui:getScoreComboMultipler()
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

function lwui:setMaxStamina(val)
	self.maxStamina = math.min(assert(val > 0 and val, "invalid value"), 99)
	self.stamina = self.maxStamina
	self.staminaInterpolate = self.stamina
end

function lwui:getMaxStamina()
	return self.maxStamina
end

function lwui:getStamina()
	return self.stamina
end

function lwui:addStamina(val)
	val = math.floor(val)
	if val == 0 then return end

	self.stamina = util.clamp(self.stamina + val, 0, self.maxStamina)

	if self.staminaTimer then
		self.timer:cancel(self.staminaTimer)
		self.staminaTimer = nil
	end

	self.staminaTimer = self.timer:tween(0.5, self, {staminaInterpolate = self.stamina}, "out-quart")
end

------------------
-- Pause button --
------------------

function lwui:enablePause()
	self.pauseEnabled = true
end

function lwui:disablePause()
	self.pauseEnabled = false
end

function lwui:isPauseEnabled()
	return self.pauseEnabled
end

function lwui:checkPause(x, y)
	return self:isPauseEnabled() and x >= 34 and y >= 17 and x < 63 and y < 46
end

------------------
-- Other things --
------------------

function lwui:addTapEffect(x, y, r, g, b, a)
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

function lwui:setTextScaling(scale)
	self.textScaling = scale
end

function lwui:getOpacity()
	return self.opacity
end

function lwui:setOpacity(opacity)
	self.opacity = opacity
	self.fullComboAnim:setOpacity(opacity * 255)
	self.liveClearAnim:setOpacity(opacity * 255)
end

function lwui.setComboCheer()
end

function lwui.setTotalNotes()
end

function lwui:startLiveClearAnimation(fullcombo, callback, opaque)
	if self.liveClearTime == -math.huge then
		self.pauseEnabled = false
		self.liveClearTime = fullcombo and 7 or 5
		self.liveClearCallback = callback
		self.liveClearCallbackOpaque = opaque
	end
end

function lwui:setLiveClearVoice(voice)
	self.liveClearVoice = voice
end

-------------
-- Drawing --
-------------

local function setColor(warn, r, g, b, a)
	local warnLerp = warn / 0.25
	local c1, c2, c3, c4

	if type(r) == "table" then
		c1 = util.lerp(r[1], 217, warnLerp)
		c2 = util.lerp(r[2], 62, warnLerp)
		c3 = util.lerp(r[3], 52, warnLerp)
		c4 = util.lerp(r[4] or g or 255, a or 255, warnLerp)
	else
		c1 = util.lerp(r, 217, warnLerp)
		c2 = util.lerp(g, 62, warnLerp)
		c3 = util.lerp(b, 52, warnLerp)
		c4 = a
	end

	love.graphics.setColor(color.compat(c1, c2, c3, c4))
end

function lwui:drawHeader()
	-- Placement
	setColor(self.staminaWarningDuration, 255, 190, 63, self.opacity)
	love.graphics.rectangle("fill", 190, 21, 140, 24, 4, 4)
	love.graphics.rectangle("line", 190, 21, 140, 24, 4, 4)
	setColor(self.staminaWarningDuration, 249, 141, 81, self.opacity)
	love.graphics.rectangle("fill", 630, 21, 140, 24, 4, 4)
	love.graphics.rectangle("line", 630, 21, 140, 24, 4, 4)

	-- Stamina bar
	local lz = love.graphics.getLineWidth()
	love.graphics.stencil(self.staminaStencil, "increment", 1)
	love.graphics.setStencilTest("greater", 0)
	setColor(self.staminaWarningDuration, self.scoreGlowColor, self.opacity)
	love.graphics.rectangle("fill", 16, 60, 928, 16, 8, 8)
	love.graphics.setStencilTest()
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.setLineWidth(4)
	love.graphics.rectangle("line", 18, 60, 924, 18, 10, 10)
	love.graphics.setLineWidth(lz)

	-- Text
	local shader = love.graphics.getShader()
	love.graphics.setShader(util.drawText.workaroundShader)
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

function lwui:drawStatus()
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
	local nicScale = 0.75 - self.noteIconTime * 0.15
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
		local flash = self.liveClearTime > 5 and self.fullComboAnim or self.liveClearAnim
		flash:draw(480, 320)
	end
end

return lwui
