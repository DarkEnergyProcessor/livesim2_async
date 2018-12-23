-- Lovewing Live UI (SIF: Redefined)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Yohane = require("libs.Yohane")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local vector = require("libs.hump.vector")

local assetCache = require("asset_cache")
local audioManager = require("audio_manager")
local cache = require("cache")
local color = require("color")
local util = require("util")

local uibase = require("game.live.uibase")

local lwui = Luaoop.class("livesim2.LovewingLiveUI", uibase)

------------------
-- FBO creation --
------------------

local function newFBO(w, h)
	-- Personally I try to avoid Canvas
	-- because it can be very wrong
	-- in highDPI systems.
	if util.compareLOVEVersion(11, 0) >= 0 then
		return love.graphics.newCanvas(w, h, {dpiscale = 1})
	else
		return love.graphics.newCanvas(w, h)
	end
end

local function HSL(h, s, l, a)
	if s<=0 then return l,l,l,a end
	h, s, l = h/256*6, s/255, l/255
	local c = (1-math.abs(2*l-1))*s
	local x = (1-math.abs(h%2-1))*c
	local m,r,g,b = (l-.5*c), 0,0,0
	if h < 1     then r,g,b = c,x,0
	elseif h < 2 then r,g,b = x,c,0
	elseif h < 3 then r,g,b = 0,c,x
	elseif h < 4 then r,g,b = 0,x,c
	elseif h < 5 then r,g,b = x,0,c
	else              r,g,b = c,0,x
	end return (r+m)*255,(g+m)*255,(b+m)*255,a
end

local function createGlowScore(blur)
	local a, b = newFBO(960, 96), newFBO(960, 96)
	blur:send("resolution", {960, 96})

	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setColor(color.white)
	love.graphics.setCanvas(a)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.clear(255, 255, 255, 0)
	love.graphics.rectangle("fill", 40, 40, 880, 16)
	love.graphics.setShader(blur)

	for i = 3, 1, -1 do
		love.graphics.setCanvas(b)
		love.graphics.clear(color.white0PT)
		blur:send("direction", {0, i})
		love.graphics.draw(a)
		love.graphics.setCanvas(a)
		love.graphics.clear(color.white0PT)
		blur:send("direction", {i, 0})
		love.graphics.draw(b)
	end

	love.graphics.setCanvas({b, stencil = true})
	love.graphics.clear(color.white0PT)
	love.graphics.setShader()
	love.graphics.setStencilTest("less", 1)
	love.graphics.stencil(function() love.graphics.rectangle("fill", 44, 44, 872, 8) end, "increment")
	love.graphics.draw(a)
	love.graphics.setStencilTest()
	love.graphics.pop()

	return b
end

local function createStaminaBar()
	local a = newFBO(150, 150)
	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setLineWidth(12)
	love.graphics.setColor(color.white)
	love.graphics.setCanvas(a)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.circle("line", 75, 75, 62.5)
	love.graphics.pop()

	return a
end

local function createStaminaOutline(blur)
	local a, b = newFBO(150, 150), newFBO(150, 150)
	blur:send("resolution", {150, 150})

	love.graphics.push("all")
	love.graphics.origin()
	love.graphics.setColor(color.white)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setCanvas(a)
	love.graphics.setLineWidth(2)
	love.graphics.clear(color.white0PT)
	love.graphics.circle("line", 75, 75, 68)
	love.graphics.circle("line", 75, 75, 57)
	love.graphics.setShader(blur)

	love.graphics.setCanvas(b)
	love.graphics.clear(color.white0PT)
	blur:send("direction", {0, 0.4})
	love.graphics.draw(a)

	love.graphics.setCanvas(a)
	love.graphics.clear(color.white0PT)
	blur:send("direction", {0.4, 0})
	love.graphics.draw(b)
	love.graphics.pop()

	return a
end

-----------------
-- Base system --
-----------------

local scoreGlowColor = {
	{255, 255, 153},    -- No score
	{0, 255, 255},      -- C score
	{255, 153, 68},     -- B score
	{255, 153, 153},    -- A score
	{187, 170, 255}     -- S score
}

function lwui:__construct(autoplay, mineff)
	self.timer = timer.new()
	self.fonts = assetCache.loadMultipleFonts({
		{"fonts/Venera-700.otf", 14},
		{"fonts/Venera-700.otf", 22},
		{"fonts/Venera-700.otf", 43},
		{"fonts/Venera-700.otf", 68},
	})
	self.images = assetCache.loadMultipleImages({
		"assets/image/live/lw_center.png",
		"assets/image/live/lw_pause.png",
		"assets/image/dummy.png"
	}, {mipmaps = true})

	-- variable setup
	self.opacity = 1
	self.textScaling = 1
	self.autoplay = false
	self.totalNotes = 0
	self.tappedNotes = 0
	self.notesText = love.graphics.newText(self.fonts[1])
	self.noteIconTime = 0
	self.modeText = love.graphics.newText(self.fonts[1])
	self.modeText:addf(autoplay and "Autoplay" or "Live!", 250, "right", 0, 0)
	self.tapEffectList = {}
	self.pauseEnabled = true
	-- score
	self.currentScore = 0
	self.currentScoreDisplay = 0
	self.scoreTimer = nil
	self.scoreBarFlash = 0
	self.scoreGlowColor = scoreGlowColor[1]
	self.scoreBorders = {1, 2, 3, 4}
	-- combo
	self.currentCombo = 0
	self.maxCombo = 0
	self.comboScale = 1.5
	self.comboText = love.graphics.newText(self.fonts[1], "combo x")
	self.comboTimer = nil
	-- stamina
	self.maxStamina = 45
	self.stamina = 45
	self.staminaInterpolate = 45
	self.staminaTimer = nil
	self.staminaIconValue = 0
	self.staminaStencil = function()
		love.graphics.arc(
			"fill", 480, 160, 72,
			-self.staminaInterpolate / self.maxStamina * 2 * math.pi - math.pi/2,
			-math.pi/2
		)
	end
	-- Judgement
	self.judgementText = love.graphics.newText(self.fonts[4])
	self.judgementOpacity = 0
	self.judgementScale = 0
	self.judgementTimer1 = nil
	self.judgementTimer2 = nil

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

	-- image generation
	local blur = love.graphics.newShader [[
	extern vec2 resolution;
	extern vec2 direction;

	// https://github.com/Jam3/glsl-fast-gaussian-blur
	vec4 blur5(Image image, vec2 uv) {
		vec4 color = vec4(0.0);
		vec2 off1 = vec2(1.3333333333333333) * direction;
		color += Texel(image, uv) * 0.29411764705882354;
		color += Texel(image, uv + (off1 / resolution)) * 0.35294117647058826;
		color += Texel(image, uv - (off1 / resolution)) * 0.35294117647058826;
		return color;
	}

	vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
	{
		return blur5(tex, tc) * color;
	}
	]]
	self.glowScore = createGlowScore(blur)
	self.staminaBar = createStaminaBar()
	self.staminaOutline = createStaminaOutline(blur)
end

function lwui:update(dt, paused)
	-- timer
	if not(paused) then
		self.timer:update(dt)
	end

	-- Score
	if self.currentScoreDisplay >= self.scoreBorders[4] then
		self.scoreGlowColor = scoreGlowColor[5]
	elseif self.currentScoreDisplay >= self.scoreBorders[3] then
		self.scoreGlowColor = scoreGlowColor[4]
	elseif self.currentScoreDisplay >= self.scoreBorders[2] then
		self.scoreGlowColor = scoreGlowColor[3]
	elseif self.currentScoreDisplay >= self.scoreBorders[1] then
		self.scoreGlowColor = scoreGlowColor[2]
	else
		self.scoreGlowColor = scoreGlowColor[1]
	end

	-- stamina
	local value = 1 - self.staminaInterpolate / self.maxStamina
	self.staminaIconValue = (self.staminaIconValue + dt * (value + 1)) % 1

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

	self.scoreBarFlash = 1
	self.scoreTimer = self.timer:tween(0.3, self, {
		currentScoreDisplay = self.currentScore,
		scoreBarFlash = 0
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
	local h = self.fonts[4]:getHeight()

	self.judgementText:clear()
	if judgement == "perfect" then
		self.judgementText:addf({color.white, "PERFECT"}, 960, "center", -480, h * -0.5)
	elseif judgement == "great" then
		self.judgementText:addf({color.cyan, "GREAT"}, 960, "center", -480, h * -0.5)
	elseif judgement == "good" then
		self.judgementText:addf({color.hexFFFF99, "GOOD"}, 960, "center", -480, h * -0.5)
		breakCombo = true
	elseif judgement == "bad" then
		self.judgementText:addf({color.hexFF9999, "BAD"}, 960, "center", -480, h * -0.5)
		breakCombo = true
	elseif judgement == "miss" then
		self.judgementText:addf({color.hexBBAAFF, "MISS"}, 960, "center", -480, h * -0.5)
		breakCombo = true
	else
		error("invalid judgement '"..tostring(judgement).."'", 2)
	end

	-- combo things
	if addcombo then
		self.tappedNotes = self.tappedNotes + 1
		self.notesText:clear()
		self.notesText:add(string.format("Notes %d/%d", (self.totalNotes - self.tappedNotes), self.totalNotes))

		if self.comboTimer then
			self.timer:cancel(self.comboTimer)
			self.comboTimer = nil
		end
	end

	if breakCombo then
		self.currentCombo = 0
	elseif addcombo then
		self.currentCombo = self.currentCombo + 1
		self.maxCombo = math.max(self.maxCombo, self.currentCombo)
		self.comboScale = 1.5
		self.comboTimer = self.timer:tween(0.25, self, {comboScale = 1}, "out-sine")
	end

	-- judgement things
	if self.judgementTimer1 then
		self.timer:cancel(self.judgementTimer1)
		self.judgementScale = 0
		self.judgementTimer1 = nil
	end

	if self.judgementTimer2 then
		self.timer:cancel(self.judgementTimer2)
		self.judgementOpacity = 1
		self.judgementTimer2 = nil
	end

	self.judgementTimer1 = self.timer:tween(0.6, self, {judgementScale = 1}, "out-expo")
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
	self.stamina = math.min(self.maxStamina, self.stamina)
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
	self.timer:tween(0.4, tap, {scale = 2}, "out-cubic", tap.func)
	self.timer:tween(0.4, tap, {opacity = 0})

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
	self.comboCheerAnim:setOpacity(opacity * 255)
end

function lwui:setComboCheer(enable)
	self.comboCheer = not(not(enable))
end

function lwui:setTotalNotes(notes)
	self.totalNotes = notes
	self.notesText:clear()
	self.notesText:add(string.format("Notes %d/%d", (notes - self.tappedNotes), notes))
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

local staminaDrawColor = {0, 0, 0, 0}

function lwui:drawHeader()
	-- Text
	love.graphics.setColor(color.compat(58, 244, 102, self.opacity))
	love.graphics.draw(self.modeText, 650, 56)
	love.graphics.setColor(color.compat(255, 252, 2, self.opacity))
	love.graphics.draw(self.notesText, 62, 56)

	-- Score
	love.graphics.setColor(color.white)
	love.graphics.setFont(self.fonts[3])
	love.graphics.printf(tostring(math.floor(self.currentScoreDisplay + 0.5)), 0, 15, 960, "center")
	love.graphics.setColor(color.hexCFCFCF)
	love.graphics.rectangle("fill", 44, 84, 872, 8)
	love.graphics.rectangle("line", 44, 84, 872, 8)
	love.graphics.setColor(color.compat(
		self.scoreGlowColor[1],
		self.scoreGlowColor[2],
		self.scoreGlowColor[3],
		self.opacity
	))
	local w = util.clamp(self.currentScoreDisplay / self.scoreBorders[4], 0, 1) * 872
	love.graphics.rectangle("fill", 44, 84, w, 8)
	love.graphics.rectangle("line", 44, 84, w, 8)
	love.graphics.draw(self.glowScore, 0, 40)
	love.graphics.setColor(color.compat(255, 255, 255, self.scoreBarFlash * self.opacity))
	love.graphics.rectangle("fill", 44, 84, 872, 8)
	love.graphics.rectangle("line", 44, 84, 872, 8)

	-- Pause button
	if self.pauseEnabled then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
		love.graphics.draw(self.images[2], 38, 21, 0, 0.19, 0.19)
	end

	-- Stamina
	local value = self.staminaInterpolate / self.maxStamina
	staminaDrawColor[1],
	staminaDrawColor[2],
	staminaDrawColor[3],
	staminaDrawColor[4] = color.compat(HSL(85.33 * value, 193.8, 160, self.opacity))
	love.graphics.setColor(staminaDrawColor)
	love.graphics.setStencilTest("greater", 0)
	love.graphics.stencil(self.staminaStencil, "increment")
	love.graphics.draw(self.staminaBar, 480, 160, 0, 0.75, 0.75, 75, 75)
	love.graphics.setStencilTest()
	love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
	love.graphics.draw(self.staminaOutline, 480, 160, 0, 0.75, 0.75, 75, 75)
end

function lwui:drawStatus()
	-- Tap effect
	for i = #self.tapEffectList, 1, -1 do
		local tap = self.tapEffectList[i]
		if tap.done then break end

		love.graphics.setColor(color.compat(tap.r, tap.g, tap.b, tap.a * tap.opacity * self.opacity))
		love.graphics.draw(self.images[3], tap.x, tap.y, 0, tap.scale, tap.scale, 64, 64)
	end

	-- Judgement
	if self.judgementOpacity > 0 then
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity * self.judgementOpacity))
		love.graphics.draw(self.judgementText, 480, 320, 0, self.judgementScale * self.textScaling)
	end

	-- Combo
	if self.currentCombo > 0 then
		local value = tostring(self.currentCombo)
		local w = self.fonts[2]:getWidth(value)
		love.graphics.setColor(color.compat(255, 255, 255, self.opacity))
		love.graphics.draw(self.comboText, 392, 232)
		-- TODO: Use better way to draw this
		love.graphics.push()
		love.graphics.setFont(self.fonts[2])
		love.graphics.translate(w * 0.5 + 490, 238)
		love.graphics.scale(self.comboScale, self.comboScale)
		love.graphics.print(value, -w * 0.5, -13)
		love.graphics.pop()
	end

	-- Musical icon
	love.graphics.setColor(staminaDrawColor)
	local w = (1 - self.staminaIconValue) * 0.1
	love.graphics.draw(self.images[1], 480, 160, 0, 0.47 + w, 0.47 + w, 55, 59.5)
	w = self.staminaIconValue * 0.2
	love.graphics.setColor(
		staminaDrawColor[1],
		staminaDrawColor[2],
		staminaDrawColor[3],
		staminaDrawColor[4] * (self.staminaIconValue * self.staminaIconValue - 2 * self.staminaIconValue + 1)
	)
	love.graphics.draw(self.images[1], 480, 160, 0, 0.57 + w, 0.57 + w, 55, 59.5)

	-- Live clear
	if self.liveClearTime ~= -math.huge then
		local flash = self.liveClearTime > 5 and self.fullComboAnim or self.liveClearAnim
		flash:draw(480, 320)
	end
end

return lwui
