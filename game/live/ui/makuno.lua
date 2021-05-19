-- Makuno Live UI v.1.2a
-- Contributed by Makuno, slightly modified
-- part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local vector = require("libs.nvec")

local assetCache = require("asset_cache")
local audioManager = require("audio_manager")
local setting = require("setting")

local color = require("color")
local util = require("util")

local uibase = require("game.live.uibase")

local mknui = Luaoop.class("livesim2.MakunoLiveUI", uibase)

-----------------
-- Local Stuff --
-----------------

local scr = {
	text = {
		"D","C","B","A","S","SS","SSS","SPI","UPI"
	},

	color = {
		{255, 255, 255},	-- D
		{0, 255, 255},		-- C	(30%)
		{255, 150, 50},		-- B	(50%)
		{255, 115, 115},	-- A	(70%)
		{221, 136, 255},	-- S	(100%)
		---
		{255, 220, 85},		-- SS	(x2 of S)
		{143, 231, 255},	-- SSS	(x3 of S)
		{255, 10, 215},		-- SPI	(x6 of S)
		{255, 50, 50},		-- UPI	(x9 of S)
	},
}

local l = {

	--[[	uxs - UseExtendedScore
		If 'true' use rank that exceed S.
	]]
	ds_uxs = false,

	--[[	esm - ExtendScoreMode (If UseExtendedScore: true)
		1 - All extend ranks will display at once.
		2 - Display SS/SSS after reached S,
			and SPI/UPI after reached SSS.
		3 - Only display SS/SSS after reached S,
			not display SPI/UPI
	]]
	ds_esm = 2,

	--[[	casm - ComboAffectScoreMultiplier
		0 - Combo does affect the Score Multiplier.
		1 - Combo doesn't affect the Score Multiplier.
	]]
	ds_casm = 1,

	--[[	adm - AccuracyDisplayMode
		1 - Start with 100%, decrease depend on judgements.
		2 - Start with 0%, increase depend on judgements.
	]]
	ds_adm = 2,

	--[[	fsne - ForceStrictNoEffects
		0 - Don't Force Strict (Depend on LS2 settings)
		1 - Force Strict (Regardless of LS2 settings all effects will turn off)
	]]
	ds_fsne = 0,

	--[[	dpy - DisplayingMode (Only Left side of the UI)
		1 - Display Only Accuracy
		2 - Display Only Accuracy Score
	]]
	ds_dpy = 1,

	--[[	sbt - Scorebar Type
		1 - Display v.1.0 - v.1.1 Scorebar (Display only Scorerank Bar)
		2 - Display v.1.2+ Scorebar (Scorerank Bar + PIGI Ratio + EX-Score)
	]]
	ds_sbt = 2,
	
	--[[	sof - Stamina Overflow
		If 'true' will allow heal skill to continue fill the stamina bar
		even It already full. (Similar to new Stamina system in SIF)
	]]
	ds_sof = true,
}

local fonts = {
	Li = "fonts/Jost-Light.ttf",
	Re = "fonts/Jost-Regular.ttf",
	It = "fonts/Jost-Italic.ttf",
	Me = "fonts/Jost-Medium.ttf",
}

local function setColor(r, g, b, a)
	local c1, c2, c3, o

	if type(r) == "table" then
		c1 = util.clamp(r[1], 0, 255)
		c2 = util.clamp(r[2], 0, 255)
		c3 = util.clamp(r[3], 0, 255)
		o = util.clamp(r[4] or g or 255, 0, a or 255)
	else
		c1 = util.clamp(r, 0, 255)
		c2 = util.clamp(g, 0, 255)
		c3 = util.clamp(b, 0, 255)
		o = a or 1
	end

	love.graphics.setColor(color.compat(c1, c2, c3, o))
end

local function drawLine(dir, line, pos_s, pos_e)
	if dir == nil then return end

	if dir == "vertical" then
		love.graphics.line(line, pos_s, line, pos_e)
	elseif dir == "horizontal" then
		love.graphics.line(pos_s, line, pos_e, line)
	end
end

local function retrieveTheme(i)
	if i then
		return {scr.color[i][1], scr.color[i][2], scr.color[i][3]}
	else
		return {scr.color[1][1], scr.color[1][2], scr.color[1][3]}
	end
end

local function addLine(ma, ba, s, os)
	local tl = {}

	for i = 1, ma do
		tl[#tl + 1] = (util.clamp(ba[i] / ba[ma], 0, 1) * s) + os
	end

	return tl
end

--------------------
-- Core:Construct

function mknui:__construct(autoplay, mineff)
	self.timer = timer:new()
	self.fonts = assetCache.loadMultipleFonts({
		{fonts.Me, l.ds_sbt == 1 and 15 or 13},   -- Head Title (SCORE and STAMINA)
		{fonts.Li, l.ds_sbt == 1 and 40 or 36}, -- Score & Acc
		{fonts.It, 15}, -- Autoplay
		{fonts.Li, 21},	-- Judgements
		{fonts.Re, 20}, -- Combo
		{fonts.Li, 45},	-- End Screen (FC/LC/Fail)
		{fonts.Li, 22},	-- End Screen 'Live'
		{fonts.It, 20},	-- Score Added
		--
		{fonts.Re, 14},   -- Sub Info (v.1.2)
		{fonts.Me, 13},   -- Overflow Count & Stamina (v.1.2)
	})
	self.fonts_hc = {
		self.fonts[3]:getHeight() * -0.5,
		self.fonts[4]:getHeight() * -0.5,
		self.fonts[5]:getHeight() * -0.5,
		self.fonts[6]:getHeight() * -0.5,
		self.fonts[7]:getHeight() * -0.5,
	}
	self.images = assetCache.loadMultipleImages(
		{
			"assets/image/dummy.png",
		},	{mipmaps = true}
	)
	self.text = {
		Top = {
			SCORE = "SCORE",
			ACC = "ACCURACY",
			JUDGE = "JUDGEMENTS",
			AUTO = "AUTOPLAY",
			PIGI = "PIGI Ratio",
			EXSCORE = "EX-SCORE",
		},

		Result = {
			L = "L I V E",
			F = "F A I L E D",
			FM = "F U L L  M I S S E D",
			C = "C L E A R E D",
			FC = "F U L L  C O M B O",
			PF = "P E R F E C T",
		},

		Judge = {
			Perfect = "PERFECT",
			Great = "GREAT",
			Good = "GOOD",
			Bad = "BAD",
			Miss = "MISS",
		},
	}
	---- thing #1
	self.pauseEnabled = true
	self.tapEffectList = {}
	self.scoreAddEffectList = {}
	--
	self.staminaFunction = setting.get("STAMINA_FUNCTIONAL") == 1
	self.minimalEffect = mineff
	self.autoplaying = autoplay
	--
	self.nameDisplay = nil

	----
	self.dis_opacity = 1
	self.dis_textscaling = 1
	--
	self.tween_dis_opacity = nil

	---- thing #2
	self.currentscore = 0
	self.currentscore_2 = 0
	self.current_exscore = 0
	self.currentscoreAdd = 0
	--
	self.dis_score = self.currentscore
	self.dis_score_2 = self.currentscore_2
	self.dis_ex_score = self.current_exscore
	--
	self.sc_bars = {1, 2, 3, 4, 5, 6, 7, 8, 9}
	self.sc_rc = retrieveTheme()
	self.dis_currentrank = scr.text[1]
	--
	self.tween_time_score = nil
	self.tween_time_score_2 = nil
	self.tween_dis_ex_score = nil
	self.tween_dis_sc_rc = nil

	---- Combo #3
	self.currentcombo = 0
	self.miss_combo = 0
	self.highestcombo = 0
	--
	self.dis_opacity_combo = 1
	--
	self.tween_dis_combo = nil

	---- Stam #4
	self.currentstamina = 9
	self.maxstamina = 9
	--
	self.currentoverflow = 0
	self.overflow_bonus = 0
	self.overflow_multiply = 0
	self.maxoverflow_bonus = 10
	--
	self.dis_stamina = 100
	self.dis_overflow_stamina = 0
	self.dis_stamina_color1 = {35, 35, 35}
	self.dis_stamina_color2 = {240, 240, 240}
	self.dis_overflow_color = {50, 175, 255}
	self.dis_overflow = {o = 0, t = 8}
	--
	self.tween_stamina = nil
	self.tween_stamina_of = nil
	self.tween_stamina_color = nil
	self.tween_stamina_color2 = nil
	self.tween_overflow = nil

	---- Judge #5
	self.dis_opacity_judge = 1
	self.dis_scale_judge = 1.1
	--
	self.count_perfect = 0
	self.count_great = 0
	self.count_good = 0
	self.count_bad = 0
	self.count_miss = 0
	--
	self.PIGI_ratio = 0
	--
	self.tween1_judge = nil
	self.tween2_judge = nil

	---- Acc #6
	self.totalnote = 0
	self.tn = 0
	self.totalnotescore = 0
	self.acc = 0
	self.dis_acc = 0
	--
	self.tween_dis_acc = nil

	---- Result #7
	self.PUC = true
	self.FC = true
	self.MC = true
	--
	self.audio_liveclearvoice = nil
	self.audio_livefailvoice = nil
	self.check_liveclearvoiceplayed = false
	self.check_livefailvoiceplayed = false
	--

	---- Other #8
	self.time_live_pre = 5
	self.time_live_postend = -math.huge
	self.maj_LCCB = nil
	self.maj_LCCBO = nil
	self.check_dispause = false
	self.pause = {
		o = 1,
	}
	self.other_tween = {
		dim = 0,
		----
		re_b_o = 0,
		re_b_s = 1.1,
		re_s_o = 0,
		--
		re_b_x = 480,
		re_b_y = 320,
		re_s_x = 320,
		re_s_y = 280,
		----
		fe_r_y = 924,
		----
		color = {0, 0, 0},
	}

	---- Text #9
	self.judgeText = love.graphics.newText(self.fonts[4])
	--
	self.resultText = love.graphics.newText(self.fonts[6])
	self.resultText_small = love.graphics.newText(self.fonts[7])

end

------------------------------------------------------------
-- Data Retrieving

function mknui:getNoteSpawnPosition()
	return vector(480, 160)
end

function mknui:getLanePosition()
	return {
		vector(816+64, 96+64 ), -- 9 (Right)
		vector(785+64, 249+64), -- 8
		vector(698+64, 378+64), -- 7
		vector(569+64, 465+64), -- 6
		vector(416+64, 496+64), -- 5 (Center)
		vector(262+64, 465+64), -- 4
		vector(133+64, 378+64), -- 3
		vector(46+64 , 249+64), -- 2
		vector(16+64 , 96+64 ), -- 1 (Left)
	}
end

function mknui:getFailAnimation()
	local TRACKLOST = {
		t = timer:new();
		--
		fail_t = love.graphics.newText(self.fonts[6]),
		fail_t_small = love.graphics.newText(self.fonts[7]),
		--
		fa_dim = 0,
		--
		fa_s_x = -320,
		--
		fa_b_o = 0,
		fa_b_s = 1.1,
		fa_s_o = 0,
	}

	TRACKLOST.fail_t_small:addf(
		self.text.Result.L, 240, "right", 120, self.fonts_hc[5]
	)

	TRACKLOST.fail_t:addf(
		{color.red, self.text.Result.F},
		960, "center", -480, self.fonts_hc[4]
	)

	function TRACKLOST.update(_,dt)
		TRACKLOST.t:update(dt)
	end

	function TRACKLOST:draw(_,x,y)

		love.graphics.setColor(color.compat(0, 0, 0, TRACKLOST.fa_dim))
		love.graphics.rectangle("fill", -88, -43, 1136, 726)

		setColor(255, 255, 255, TRACKLOST.fa_b_o)
		love.graphics.draw(TRACKLOST.fail_t, 480, 320, 0, TRACKLOST.fa_b_s)

		setColor(255, 255, 255, TRACKLOST.fa_s_o)
		love.graphics.draw(TRACKLOST.fail_t_small, TRACKLOST.fa_s_x, 280, 0, 1)

	end

	TRACKLOST.t:tween(500, TRACKLOST, {fa_dim = 0.1}, "out-quad")
	TRACKLOST.t:tween(500, TRACKLOST, {fa_b_s = 1, fa_s_o = 1, fa_s_x = 220}, "out-cubic")

	TRACKLOST.t:after(550, function()
		TRACKLOST.t:tween(500, TRACKLOST, {fa_b_o = 1, fa_b_s = 1}, "out-cubic")
	end)

	TRACKLOST.t:after(2750, function()
		TRACKLOST.t:tween(250, TRACKLOST, {
			fa_b_o = 0,
			fa_s_o = 0,
			fa_dim = 0,
		}, "out-cubic")
	end)

	return TRACKLOST
end

function mknui:getOpacity()
	return self.dis_opacity
end

function mknui:getMaxStamina()
	return self.maxstamina
end

function mknui:getStamina()
	return self.currentstamina
end

function mknui:getScore()
	return self.currentscore
end

function mknui:getCurrentCombo()
	return self.currentcombo
end

function mknui:getMaxCombo()
	return self.highestcombo
end

function mknui:getScoreComboMultipler()
	if l.ds_casm == 1 then
		return 1
	else
		if self.currentcombo < 50 then
			return 1
		elseif self.currentcombo < 100 then
			return 1.1
		elseif self.currentcombo < 200 then
			return 1.15
		elseif self.currentcombo < 400 then
			return 1.2
		elseif self.currentcombo < 600 then
			return 1.25
		elseif self.currentcombo < 800 then
			return 1.3
		else
			return 1.35
		end
	end
end

------------------------------------------------------------
-- Core:Update

function mknui:update(dt,paused)

	if not(paused) then
		self.time = dt
		self.timer:update(dt)
	end

	for i = (#scr.text - 1), 1, -1 do
		if self.dis_score >= self.sc_bars[i] then
			if (l.ds_uxs == false) and i > 4 then i = 4 end
			if (l.ds_uxs == true) and (l.ds_esm == 3) and i > 6 then i = 6 end

			if not(l.ds_fsne == 1) then
				if self.tween_dis_sc_rc then self.timer:cancel(self.tween_dis_sc_rc) end
				self.tween_dis_sc_rc = self.timer:tween(1, self.sc_rc, retrieveTheme(1 + i), "out-expo")
			else
				self.sc_rc = retrieveTheme(1 + i)
			end

			self.dis_currentrank = scr.text[1 + i]
			break
		end
	end
	
	if self.currentscoreAdd ~= 0 and not(self.minimalEffect) and not(l.ds_fsne == 1) then
		local scadd_new
		for s = 1,#self.scoreAddEffectList do
			local sdel = self.scoreAddEffectList[s]
			if sdel.done then
				sdel = table.remove(self.scoreAddEffectList, s)
				break
			end
		end

		if not(scadd_new) then
			scadd_new = {
				ts = nil, done = false,
				value = nil,
				text = love.graphics.newText(self.fonts[8]),
				o = 0, x = 360
			}

			scadd_new.func = function(wait)
				self.timer:tween(0.1, scadd_new, {x = 360 * 1.35, o = 1}, "out-expo")
				wait(0.15)
				self.timer:tween(0.15, scadd_new, {x = 360 * 1.75, o = 0}, "in-quart")
				wait(0.15)
				scadd_new.done = true
			end
		end

		scadd_new.text:clear()
		if self.currentscoreAdd > 0 then
			scadd_new.value = {color.white, "+ "..tostring(self.currentscoreAdd)}
        elseif self.currentscoreAdd < 0 then
			scadd_new.value = {color.red, "- "..tostring(math.abs(self.currentscoreAdd))}
        end
		scadd_new.text:addf(scadd_new.value, 480, "right", -240, self.fonts_hc[5])
		--
		scadd_new.done = false
		scadd_new.o = 0
		scadd_new.x = 360
		scadd_new.ts = self.timer:script(scadd_new.func)

		self.scoreAddEffectList[#self.scoreAddEffectList + 1] = scadd_new
		self.currentscoreAdd = 0
	end

	if self.time_live_pre > 0 then
		self.time_live_pre = self.time_live_pre - dt
	elseif self.time_live_pre <= 0 and self.check_dispause == false then
		self.check_dispause = true
		self.timer:tween(1, self.pause, {o = 0}, "out-quart")
	end

	if self.time_live_postend ~= -math.huge then
		if self.time_live_postend > 0 then
			self.time_live_postend = self.time_live_postend - dt
		end

		if self.audio_liveclearvoice and not(self.check_liveclearvoiceplayed) then
			audioManager.play(self.audio_liveclearvoice)
			self.check_liveclearvoiceplayed = true
		end

		if self.time_live_postend <= 0 and self.maj_LCCB then
			self.maj_LCCB(self.maj_LCCBO)
			self.maj_LCCB = nil
			self.maj_LCCBO = nil
		end
	end
end

--------------------
-- Primary Function

function mknui:addScore(amount) 
	
	local a = math.ceil(amount + (amount * self.overflow_multiply))

	if a == 0 then return end

	self.currentscore = self.currentscore + a
	self.currentscore_2 = (self.acc / self.totalnotescore) * 1000000
	----
	self.currentscoreAdd = self.currentscoreAdd + a

	if (l.ds_fsne == 1) then
		self.dis_score = self.currentscore
		self.dis_score_2 = self.currentscore_2
	else
		if self.tween_time_score then
			self.timer:cancel(self.tween_time_score)
			self.tween_time_score = nil
		end

		if self.tween_time_score_2 then
			self.timer:cancel(self.tween_time_score_2)
			self.tween_time_score_2 = nil
		end

		self.tween_time_score = self.timer:tween(0.5, self, {dis_score = self.currentscore}, "out-quint")
		self.tween_time_score_2 = self.timer:tween(0.5, self, {dis_score_2 = self.currentscore_2}, "out-quint")
	end
end

function mknui:comboJudgement(judgement, addcombo)
	if judgement ~= nil then
		local combochoke = false

		self.judgeText:clear()
		if judgement == "perfect" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Perfect},
				960, "center", -480, self.fonts_hc[2]
			)
			self.MC = false
			self.current_exscore = self.current_exscore + 4
		elseif judgement == "great" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Great},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.MC = false
			self.current_exscore = self.current_exscore + 2
		elseif judgement == "good" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Good},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.FC = false
			self.MC = false
			combochoke = true
			self.current_exscore = self.current_exscore - 4
		elseif judgement == "bad" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Bad},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.FC = false
			self.MC = false
			combochoke = true
			self.current_exscore = self.current_exscore - 2
		elseif judgement == "miss" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Miss},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.FC = false
			combochoke = true
			self.current_exscore = self.current_exscore - 1
		else
			self.judgeText:addf(
				{color.white, tostring(judgement)},
				960, "center", -480, self.fonts_hc[2]
			)
		end

		if combochoke then
			if (l.ds_adm == 1) then
				self.totalnote = self.totalnote + 1
			end

			self.tn = self.tn - 1
			self.currentcombo = 0

			if judgement == "good" then
				self.acc = self.acc + 0.5
				self.miss_combo = 0
				self.count_good = self.count_good + 1
			elseif judgement == "bad" then
				self.acc = self.acc + 0.25
				self.miss_combo = 0
				self.count_bad = self.count_bad + 1
			elseif judgement == "miss" then
				self.miss_combo = self.miss_combo + 1
				self.count_miss = self.count_miss + 1
			end

		elseif addcombo then
			if (l.ds_adm == 1) then
				self.totalnote = self.totalnote + 1
			end

			self.tn = self.tn - 1
			self.miss_combo = 0
			self.currentcombo = self.currentcombo + 1
			self.highestcombo = math.max(self.highestcombo, self.currentcombo)

			if judgement == "perfect" then
				self.acc = self.acc + 1
				self.count_perfect = self.count_perfect + 1
			elseif judgement == "great" then
				self.acc = self.acc + 0.75
				self.count_great = self.count_great + 1
			end
		end

		if self.totalnote > 0 then
			if (l.ds_fsne == 1) then
				self.dis_acc = (self.acc/self.totalnote) * 100
			else
				if self.tween_dis_acc then self.timer:cancel(self.tween_dis_acc) end
				self.tween_dis_acc = self.timer:tween(0.5, self, {dis_acc = (self.acc/self.totalnote) * 100}, "out-quart")
			end

			self.PIGI_ratio = self.count_perfect / (self.count_great + self.count_good + self.count_bad + self.count_miss)
		end

		if not(l.ds_fsne == 1) then
			if self.tween1_judge then
				self.timer:cancel(self.tween1_judge)
				self.dis_scale_judge = 1.1
				self.tween1_judge = nil
			end

			if self.tween_dis_ex_score then self.timer:cancel(self.tween_dis_ex_score) end

			self.tween_dis_ex_score = self.timer:tween(0.5, self, {dis_ex_score = self.current_exscore}, "out-expo")
			self.tween1_judge = self.timer:tween(0.5, self, {dis_scale_judge = 1}, "out-quart")
		end

		if self.tween2_judge then
			self.timer:cancel(self.tween2_judge)
			self.dis_opacity_judge = 1
			self.tween2_judge = nil
		end

		if self.tn == 0 then
			if self.tween_dis_combo then
				self.timer:cancel(self.tween_dis_combo)
				self.dis_opacity_combo = 1
				self.tween_dis_combo = nil
			end

			self.tween_dis_combo = self.timer:tween(1, self, {dis_opacity_combo = 0}, "in-quart")
		end

		self.tween2_judge = self.timer:tween(1, self, {dis_opacity_judge = 0}, "in-quart")
	end
end

function mknui:startLiveClearAnimation(fullcombo, callback, opaque)
	if self.time_live_postend == -math.huge then
		self.pauseEnabled = false
		self.time_live_postend = 4.5
		self.maj_LCCB = callback
		self.maj_LCCBO = opaque

		local some_x = 0

		self.timer:tween(0.5, self.other_tween, {dim = 0.35, color = {0, 0, 0}}, "out-quad")

		------
		self.resultText_small:addf(
			self.text.Result.L, 240, "left", 120, self.fonts_hc[5]
		)
		if fullcombo and (self.FC == true) and (self.PUC == true) then
			some_x = 235

			self.resultText:addf(
				{color.gold, self.text.Result.PF},
				960, "center", -480, self.fonts_hc[4]
			)

		elseif fullcombo and (self.FC == true) and not(self.PUC == true) then
			some_x = 172

			self.resultText:addf(
				{color.skyBlue, self.text.Result.FC},
				960, "center", -480, self.fonts_hc[4]
			)
		elseif not fullcombo and (self.MC == true) then
			some_x = 171

			self.resultText:addf(
				{color.red, self.text.Result.FM},
				960, "center", -480, self.fonts_hc[4]
			)
		else
			some_x = 227

			self.resultText:addf(
				self.text.Result.C,
				960, "center", -480, self.fonts_hc[4]
			)
		end
		------

		self.timer:tween(0.5, self.other_tween, {re_s_o = 1, re_s_x = some_x}, "out-cubic")

		self.timer:after(0.55, function()
			self.timer:tween(0.5, self.other_tween, {re_b_o = 1, re_b_s = 1}, "out-cubic")
		end)

		self.timer:after(4.25, function()
			self.timer:tween(0.25, self, {dis_opacity = 0}, "out-quad")
			self.timer:tween(
				0.25, self.other_tween,
				{dim = 0.67,
				re_b_y = 360,
				re_s_y = 240,
				--
				re_s_o = 0,
				re_b_o = 0,
				re_b_s = 1,
				--
				color = {100, 98, 98}
				},
				"out-cubic"
			)
			self.timer:tween(0.3, self.other_tween, {fe_r_y = 231}, "out-quart")
		end)
	end
end

function mknui:addStamina(amount)

	local a = math.ceil(amount)

	if self.staminaFunction == false then return end
	if a == 0 then return end

	local b_c1, b_c2

	if a < 0 and (l.ds_sof == true) then
		self.currentoverflow = 0
	end

	if (self.currentstamina + a) > self.maxstamina and (l.ds_sof == true) then
		local rf = self.maxstamina - self.currentstamina
		local ovf = a - rf
		self.currentstamina = util.clamp(self.currentstamina + rf, 0, self.maxstamina)
		if (self.currentoverflow + a) >= self.maxstamina then
			local ovrf = self.maxstamina - self.currentoverflow
			local ovna = a - ovrf
			self.currentoverflow = 0
			self.currentoverflow = util.clamp(self.currentoverflow + ovna, 0, self.maxstamina)

			if self.overflow_bonus >= self.maxoverflow_bonus then
				self.currentoverflow = self.maxstamina
				self.overflow_bonus = self.maxoverflow_bonus
				self.overflow_multiply = (self.maxoverflow_bonus * 0.005) + ((self.maxstamina + 10) / 500)
			else
				self.overflow_bonus = self.overflow_bonus + 1
				self.overflow_multiply = (self.overflow_bonus * 0.005) + ((self.maxstamina + 10) / 500)

				if self.tween_overflow then 
					self.timer:cancel(self.tween_overflow)
					self.tween_overflow = nil
				end
				self.dis_overflow = {o = 1, t = 0}
				self.tween_overflow = self.timer:tween(1.5, self.dis_overflow, {o = 0, t = 16}, "out-quart")
			end

		else
			self.currentoverflow = util.clamp(self.currentoverflow + ovf, 0, self.maxstamina)
		end
	else
		self.currentstamina = util.clamp(self.currentstamina + a, 0, self.maxstamina)
	end

	if (self.currentstamina / self.maxstamina) <= 0.2 then
		b_c1 = {100, 0, 0}
		b_c2 = {255, 25, 25}
	else
		b_c1 = {35, 35, 35}
		b_c2 = {225, 225, 225}
	end

	if (l.ds_fsne == 1) then
		self.dis_stamina = self.currentstamina
		self.dis_overflow_stamina = self.currentoverflow
		self.dis_stamina_color1 = b_c1
		self.dis_stamina_color2 = b_c2
	else
		if self.tween_stamina then self.timer:cancel(self.tween_stamina) self.tween_stamina = nil end
		if self.tween_stamina_of then self.timer:cancel(self.tween_stamina_of) self.tween_stamina_of = nil end

		if self.tween_stamina_color then self.timer:cancel(self.tween_stamina_color) end
		if self.tween_stamina_color2 then self.timer:cancel(self.tween_stamina_color2) end

		self.tween_stamina_color = self.timer:tween(0.15, self.dis_stamina_color1, b_c1, "out-quint")
		self.tween_stamina_color2 = self.timer:tween(0.15, self.dis_stamina_color2, b_c2, "out-quint")
		self.tween_stamina = self.timer:tween(0.1, self, {dis_stamina = self.currentstamina}, "out-quint")
		self.tween_stamina_of = self.timer:tween(0.1, self, {dis_overflow_stamina = self.currentoverflow}, "out-quint")
	end
end

function mknui:addTapEffect(x, y, r, g, b, a)
	if not(self.minimalEffect) and not(l.ds_fsne == 1) then
		local tap_e
		for tap_i = 1,#self.tapEffectList do
			local tap_list = self.tapEffectList[tap_i]
			if tap_list.d then
				tap_e = table.remove(self.tapEffectList, tap_i)
				break
			end
		end

		if not(tap_e) then
			tap_e = {
				x = 0, y = 0,
				r = 255, g = 255, b = 255,
				a = 1, o = 1, s = 1,
				d = false,
			}
			tap_e.func = function()
				tap_e.d = true
			end
		end

		tap_e.x, tap_e.y = x, y
		tap_e.r, tap_e.g, tap_e.b, tap_e.a = r, g, b, a
		tap_e.o, tap_e.s = 1, 1
		tap_e.d = false

		self.timer:tween(0.25, tap_e, {s = 2, o = 0}, "out-quart", tap_e.func)

		self.tapEffectList[#self.tapEffectList + 1] = tap_e
	end
end

-- For Set
function mknui:setOpacity(o, t, m)
	if t == nil then t = 1 end
	if o == nil then o = 1 end
	if m == nil then m = "out-quart" end

	if self.tween_dis_opacity then
		self.timer:cancel(self.tween_dis_opacity)
		self.tween_dis_opacity = nil
	end

	if (l.ds_fsne == 1) then
		self.dis_opacity = o
	else
		self.tween_dis_opacity = self.timer:tween(t, self, {dis_opacity = o}, m)
	end
end

function mknui:setSongInfo(sn)
	self.nameDisplay = tostring(sn)
end

function mknui:setTextScaling(s)

end

function mknui:setTotalNotes(tl)
	if (l.ds_adm == 2) then
		self.totalnote = tl
	end

	self.tn = tl
	self.totalnotescore = tl
end

function mknui:setMaxStamina(val)
	self.maxstamina = math.min(assert(val > 0 and val, "invalid value"), math.huge)
	self.currentstamina = self.maxstamina
	self.dis_stamina = self.currentstamina
end

function mknui:setComboCheer()

end

function mknui:setLiveClearVoice(v)
	self.audio_liveclearvoice = v
end

function mknui:setScoreRange(c, b, a, s)
	self.sc_bars[1],
	self.sc_bars[2],
	self.sc_bars[3],
	self.sc_bars[4],
	self.sc_bars[5],
	self.sc_bars[6],
	self.sc_bars[7],
	self.sc_bars[8] = c, b, a, s, (s*2), (s*3), (s*6), (s*9)
end

-- For Other Use
function mknui:enablePause()
	self.pauseEnabled = true
end

function mknui:disablePause()
	self.pauseEnabled = false
end

function mknui:isPauseEnabled()
	return self.pauseEnabled
end

function mknui:checkPause(x, y)
	return self:isPauseEnabled() and x >= 155 and y >= 0 and x < 800 and y < 64
end




--------------------
-- Primary Draw Function

function mknui:drawHeader()

	local dh = {
		score_t = tostring(self.text.Top.SCORE.." (Rank "..self.dis_currentrank..")"),
		judge_t = tostring(self.text.Top.JUDGE),
		acc_t = tostring(self.text.Top.ACC),
		scacc_t = tostring(self.text.Top.ACC.." "..self.text.Top.SCORE),
		pigi_t = tostring(self.text.Top.PIGI),
		exsc_t = tostring(self.text.Top.EXSCORE),
		--
		score_amo = string.format("%06d", self.dis_score),
		scacc_amo = string.format("%06d", self.dis_score_2),
		acc_amo = string.format("%.2f", self.dis_acc == 0 and 0 or self.dis_acc).."%",
		exscc_amo = string.format("%04d", self.dis_ex_score),
		ov_amo = "x"..tostring(self.overflow_bonus),
		sta_amo = tostring(math.floor(self.dis_stamina)),
		--
		pigi_ratio = string.format("%.3f", tostring(self.PIGI_ratio))..":1",
		--
		pause_t = "",
		--
		sta_pos = 63,
		auto_pos = 68,
		--
		sbs = 960,
		abs = 160,
		ofs = 0,
		--
		t_y2 = l.ds_sbt == 1 and 12 or 10,
	}

	do
		if self.nameDisplay ~= nil then
			setColor(255, 255, 255, self.dis_opacity * 0.5)
			love.graphics.printf(self.nameDisplay, self.fonts[4], 478, 607, 480, "right", 0)
		end

		dh.ofs = (960 - dh.sbs) / 2

		if l.ds_sbt == 2 then
			dh.sbs = dh.sbs - (dh.abs * 2)
			dh.ofs = (960 - dh.sbs) / 2

			setColor(75, 75, 75, self.dis_opacity * 0.5)
			love.graphics.rectangle("fill", 0, 56, dh.abs, 18)
			love.graphics.rectangle("fill", dh.ofs + dh.sbs, 56, dh.abs, 18)

			setColor(255, 255, 255, self.dis_opacity * 0.6)
			love.graphics.setLineWidth(1.05)
			love.graphics.rectangle("line", 0, 56, dh.abs, 18)
			love.graphics.rectangle("line", dh.ofs + dh.sbs, 56, dh.abs, 18)

			setColor(255, 255, 255, self.dis_opacity * 0.9)
			love.graphics.printf(dh.exsc_t..":", self.fonts[1], dh.ofs + dh.sbs + 3, 56, dh.abs, "left", 0)
			love.graphics.printf(dh.exscc_amo, self.fonts[9], dh.ofs + dh.sbs - 2, 55, dh.abs, "right", 0)
			love.graphics.printf(dh.pigi_t..":", self.fonts[1], 3, 56, dh.abs, "left", 0)
			love.graphics.printf(dh.pigi_ratio, self.fonts[9], -2, 55, dh.abs, "right", 0)

		end

		if not(self.minimalEffect) and not(l.ds_fsne == 1) then
			dh.sta_pos = dh.sta_pos + 12
			dh.auto_pos = dh.auto_pos + 4

			local lyne, sc_bar

			if l.ds_uxs == true then
				if l.ds_esm == 1 then
					sc_bar = util.clamp(self.dis_score / self.sc_bars[8], 0, 1) * dh.sbs
					lyne = addLine(8, self.sc_bars, dh.sbs, dh.ofs)

				elseif l.ds_esm == 2 then
					if self.dis_score < self.sc_bars[4] then
						sc_bar = util.clamp(self.dis_score / self.sc_bars[4], 0, 1) * dh.sbs
						lyne = addLine(4, self.sc_bars, dh.sbs, dh.ofs)
					elseif self.dis_score < self.sc_bars[6] then
						sc_bar = util.clamp((self.dis_score - self.sc_bars[4]) / (self.sc_bars[6] - self.sc_bars[4]), 0, 1) * dh.sbs
						lyne = {
							util.clamp((self.sc_bars[5] - self.sc_bars[4]) / (self.sc_bars[6] - self.sc_bars[4]), 0, 1) * dh.sbs + dh.ofs,
						}
					else
						sc_bar = util.clamp((self.dis_score - self.sc_bars[6]) / (self.sc_bars[8] - self.sc_bars[6]), 0, 1) * dh.sbs
						lyne = {
							util.clamp((self.sc_bars[7] - self.sc_bars[6]) / (self.sc_bars[8] - self.sc_bars[6]), 0, 1) * dh.sbs + dh.ofs,
						}
					end
				else
					if self.dis_score < self.sc_bars[4] then
						sc_bar = util.clamp(self.dis_score / self.sc_bars[4], 0, 1) * dh.sbs
						lyne = addLine(4, self.sc_bars, dh.sbs, dh.ofs)
					else
						sc_bar = util.clamp((self.dis_score - self.sc_bars[4]) / (self.sc_bars[6] - self.sc_bars[4]), 0, 1) * dh.sbs
						lyne = {
							ly_SS = util.clamp((self.sc_bars[5] - self.sc_bars[4]) / (self.sc_bars[6] - self.sc_bars[4]), 0, 1) * dh.sbs + dh.ofs,
						}
					end
				end
			else
				sc_bar = util.clamp(self.dis_score / self.sc_bars[4], 0, 1) * dh.sbs
				lyne = addLine(4, self.sc_bars, dh.sbs, dh.ofs)
			end

			setColor(75, 75, 75, self.dis_opacity * 0.5)
			love.graphics.rectangle("fill", dh.ofs, 63, dh.sbs, 4)

			if sc_bar ~= nil and sc_bar > 0 then
				setColor(self.sc_rc, self.dis_opacity * 0.9)
				love.graphics.rectangle("fill", dh.ofs, 63, sc_bar, 4)
			end

			setColor(255, 255, 255, self.dis_opacity * 0.6)
			love.graphics.setLineWidth(1.05)
			love.graphics.rectangle("line", dh.ofs, 63, dh.sbs, 4)

			if lyne ~= nil then
				for i,v in pairs(lyne) do
					drawLine("vertical", v, 63, 67)
				end
			end

			for e = #self.scoreAddEffectList, 1, -1 do
				local sael = self.scoreAddEffectList[e]
				if sael.done then break end
				setColor(255, 255, 255, self.dis_opacity * sael.o)
				love.graphics.draw(sael.text, sael.x, 44, 0, 1, 1, 0, 0)
			end

		else
			dh.auto_pos = dh.auto_pos + 5
			dh.sta_pos = dh.sta_pos + 11

			setColor(255, 255, 255, self.dis_opacity * 0.6)
			love.graphics.setLineWidth(1.25)
			drawLine("horizontal", 65, dh.ofs, dh.ofs + dh.sbs)
		end

		if (self.staminaFunction) then
			dh.auto_pos = dh.auto_pos + 8

			local sta_bar, of_bar
			sta_bar = util.clamp(self.dis_stamina / self.maxstamina, 0, 1) * (dh.abs * 2)
			of_bar = util.clamp(self.dis_overflow_stamina / self.maxstamina, 0, 1) * (dh.abs * 2)

			setColor(self.dis_stamina_color1, self.dis_opacity * 0.7)
			love.graphics.rectangle("fill", dh.sbs/2, dh.sta_pos, dh.abs * 2, 4)
			setColor(self.dis_stamina_color2, self.dis_opacity * 0.85)
			love.graphics.rectangle("fill", dh.sbs/2, dh.sta_pos, sta_bar, 4)
			love.graphics.printf(dh.sta_amo, self.fonts[10], 645, dh.sta_pos - 7, dh.abs, "left", 0)
			setColor(self.dis_overflow_color, self.dis_opacity * 0.9)
			love.graphics.rectangle("fill", dh.sbs/2, dh.sta_pos, of_bar, 4)

			if self.overflow_bonus > 0 then
				setColor(self.dis_overflow_color, self.dis_opacity * 0.95)
				love.graphics.printf(dh.ov_amo, self.fonts[10], 155, dh.sta_pos - 7, dh.abs, "right", 0)
			end

			setColor(self.dis_overflow_color, self.dis_opacity * 0.9 * self.dis_overflow.o)
			love.graphics.setLineWidth(self.dis_overflow.t)
			love.graphics.rectangle("fill", dh.sbs/2, dh.sta_pos, dh.abs * 2, 4)

		end

		setColor(255, 255, 255, self.dis_opacity * 0.95)
		love.graphics.printf(dh.score_t, self.fonts[1], 480 - 2, 1, 480, "right", 0)
		if l.ds_dpy == 1 then
			love.graphics.printf(dh.acc_t, self.fonts[1], 2, 1, 480, "left", 0)
			setColor(255, 255, 255, self.dis_opacity * 0.9)
			love.graphics.printf(dh.acc_amo, self.fonts[2], 2, dh.t_y2, 480, "left", 0)
		elseif l.ds_dpy == 2 then
			love.graphics.printf(dh.scacc_t, self.fonts[1], 2, 1, 480, "left", 0)
			setColor(self.sc_rc, self.dis_opacity * 0.9)
			love.graphics.printf(dh.scacc_amo, self.fonts[2], 2, dh.t_y2, 480, "left", 0)
		end
		setColor(self.sc_rc, self.dis_opacity * 0.9)
		love.graphics.printf(dh.score_amo, self.fonts[2], 480 - 2, dh.t_y2, 480, "right", 0)

		if (self.autoplaying) then
			setColor(255, 255, 255, self.dis_opacity * 0.9)
			love.graphics.printf(self.text.Top.AUTO, self.fonts[3], 0, dh.auto_pos, 960, "center", 0)
		end
	end

	if util.isMobile() then
		dh.pause_t = "Tap inside this area to pause live."
	else
		dh.pause_t = "Click inside this area to pause live."
	end

	if self.pauseEnabled then

		setColor(150, 210, 255, self.dis_opacity * self.pause.o)
		local gra = util.gradient("vertical", color.hex99d5ff70, color.transparent)
		love.graphics.draw(gra, 160, 0, 0, 640, 64)
		love.graphics.printf(dh.pause_t, self.fonts[3], 0, 5, 960, "center", 0)

	end

end

function mknui:drawStatus()

	if not(self.minimalEffect) and not(l.ds_fsne == 1) then
		for e = #self.tapEffectList, 1, -1 do
			local tel_i = self.tapEffectList[e]
			if tel_i.d then break end

			setColor(tel_i.r, tel_i.g, tel_i.b, tel_i.a * tel_i.o)
			love.graphics.draw(self.images[1], tel_i.x, tel_i.y, 0, tel_i.s, tel_i.s, 64, 64)
		end
	end

	if self.currentcombo > 1 or self.miss_combo > 4 then
		if self.currentcombo > 0 and self.miss_combo == 0 then
			setColor(255, 255, 255, self.dis_opacity * self.dis_opacity_combo * 0.9)
			love.graphics.printf(self.currentcombo, self.fonts[5], 0, 419, 960, "center", 0)
		else
			setColor(255, 55, 55, self.dis_opacity * self.dis_opacity_combo * 0.9)
			love.graphics.printf(self.miss_combo, self.fonts[5], 0, 419, 960, "center", 0)
		end
	end

	if self.judgeText and self.dis_opacity_judge > 0 then
		setColor(255, 255, 255, self.dis_opacity * self.dis_opacity_judge * 0.95)
		love.graphics.draw(self.judgeText, 480, 470, 0, self.dis_textscaling * self.dis_scale_judge)
	end

	if self.time_live_postend ~= math.huge then
		setColor(self.other_tween.color, self.other_tween.dim)
		love.graphics.rectangle("fill", -88, -43, 1136, 726)

		setColor(255, 255, 255, 1)
		love.graphics.rectangle("fill", -88, self.other_tween.fe_r_y, 1136, 452)

		setColor(255, 255, 255, self.other_tween.re_b_o)
		love.graphics.draw(self.resultText, self.other_tween.re_b_x,  self.other_tween.re_b_y, 0, self.other_tween.re_b_s)

		setColor(255, 255, 255, self.other_tween.re_s_o)
		love.graphics.draw(self.resultText_small, self.other_tween.re_s_x, self.other_tween.re_s_y, 0, 1)
	end

end

return mknui