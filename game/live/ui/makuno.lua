-- Makuno Live UI
-- Contributed by Makuno, slightly modified
-- part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")
local vector = require("libs.nvec")

local assetCache = require("asset_cache")
local audioManager = require("audio_manager")

local color = require("color")
local util = require("util")

local uibase = require("game.live.uibase")

local mknui = Luaoop.class("livesim2.MakunoLiveUI", uibase)

-----------------
-- Local Stuff --
-----------------
local debug_settings = {
	--------------
	-- GAMEPLAY --
	--------------

	-- LIVE INTERFACE
	ScoreRules = 0,
	--[[
		0 - Same as SIF Rules
		1 - Always Round up to 10,000,000 Points on All Perfects (No ScoreAdd Animation)
	]]

	AccDisplayMode = 2,
	--[[
		1 - Start with 100%, decrease depend on judgements.
		2 - Start with 0%, increase depend on judgements.
	]]
}

local scorerank = {
	text = {
		"D","C","B","A","S","SS","SSS","SPI","UPI"
	},

	-- Prototype: Change theme color depend on LS2 system settings.
	default = {
		{255, 255, 255},	-- D
		{0, 255, 255},	  -- C	(30%)
		{255, 150, 50},	 -- B	(50%)
		{255, 115, 115},	-- A	(70%)
		{221, 136, 255},	-- S	(100%)
		---
		{255, 220, 85},	 -- SS   (x2 of S)
		{143, 231, 255},	-- SSS  (x3 of S)
		{255, 10, 215},	 -- SPI  (x6 of S)
		{255, 50, 50},	  -- UPI  (x9 of S)
	},
}

local l = {
	-- If 'true' use rank that exceed S.
	ds_uxs = false,
	--[[
		1 - All extend ranks will display at once.
		2 - Display SS/SSS after reached S, 
			and SPI/UPI after reached SSS.
		3 - Only display SS/SSS after reached S.
			not display SPI/UPI
	]]--
	ds_esm = 2,
	--[[
		0 - Combo does affect the Score Multiplier.
		1 - Combo doesn't affect the Score Multiplier.
		(Only applied when 'ScoreRules = 0')
	]]
	ds_cam = 0,
	ds_srs = debug_settings.ScoreRules,
	ds_adm = debug_settings.ScoreRules == 1 and 1 or debug_settings.AccDisplayMode,
	--[[
		0 - Regular Strict (No Score-Add effect)
		1 - Very Strict (No animation from every effect, regardless of LS2 settings)
	]]
	ds_fsne = 0,
	--[[
		1 - Display Only Accuracy
		2 - Display Only Judgements
	]]
	ds_dpy = 1,
	----
	ds_sbs = 952,
	ds_rlo = 3,
}

local function setColor(r, g, b, a)
	local c1, c2, c3, c4

	if type(r) == "table" then
		c1 = util.clamp(r[1], 0, 255)
		c2 = util.clamp(r[2], 0, 255)
		c3 = util.clamp(r[3], 0, 255)
		c4 = util.clamp(r[4] or ((g or 255) / 255), 0, a or 1)
	else
		c1 = util.clamp(r, 0, 255)
		c2 = util.clamp(g, 0, 255)
		c3 = util.clamp(b, 0, 255)
		c4 = a or 1
	end

	love.graphics.setColor(color.compat(c1, c2, c3, c4))
end

local function drawLine(direction, line, pos_start, pos_end)
	if direction == nil then return end

	if direction == "vertical" then
		love.graphics.line(line, pos_start, line, pos_end)
	elseif direction == "horizontal" then
		love.graphics.line(pos_start, line, pos_end, line)
	end
end

local function retrieveTheme(i)
	if i then
		return {scorerank.default[i][1], scorerank.default[i][2], scorerank.default[i][3]}
	else
		return {scorerank.default[1][1], scorerank.default[1][2], scorerank.default[1][3]}
	end
end

--------------------
-- Core:Construct

function mknui:__construct(autoplay, mineff, stamfunc)
	self.timer = timer:new()
	self.fonts = assetCache.loadMultipleFonts({
		{"fonts/Jost-Medium.ttf", 14},   -- Head Title (SCORE and STAMINA)
		{"fonts/Jost-Light.ttf", 40},	-- Score
		{"fonts/Jost-Italic.ttf", 15},   -- Autoplay
		{"fonts/Jost-Light.ttf", 21},	-- Judgements
		{"fonts/Jost-Regular.ttf", 23},  -- Combo Number
		{"fonts/Jost-Light.ttf", 45},	-- End Screen (FC/LC/Fail)
		{"fonts/Jost-Light.ttf", 25},	-- Score Added
		--
		{"fonts/Jost-Regular.ttf", 14},   -- Judgements
		{"fonts/Jost-Regular.ttf", 18},   -- Amount of Judgements
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
			"assets/image/live/lw_pause.png",
			"assets/image/dummy.png",
		},{mipmaps = true}
	)
	self.text = {
		Top = {
			SCORE = "SCORE",
			ACC = "ACCURACY",
			JUDGE = "JUDGEMENTS",
			AUTO = "AUTOPLAY",
		},

		Result = {
			L = "L I V E",
			F = "F A I L E D",
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
	self.staminaFunction = stamfunc ~= nil and stamfunc or false
	self.minimalEffect = mineff
	self.autoplaying = autoplay

	---- 
	self.dis_opacity = 1
	self.dis_textscaling = 1
	--
	self.tween_dis_opacity = nil

	---- thing #2
	self.currentscore = 0
	self.currentscore_2 = 0
	self.currentscoreAdd = 0
	self.dis_score = self.currentscore
	--
	self.scoreborders = {1, 2, 3, 4, 5, 6, 7, 8, 9}
	self.scorerankcolor = retrieveTheme()
	self.dis_currentrank = scorerank.text[1]
	--
	self.tween_time_scoreflash = 0 
	self.tween_time_score = nil
	self.tween_dis_scorerankcolor = nil

	---- Combo #3
	self.currentcombo = 0
	self.highestcombo = 0
	self.dis_opacity_combo = 1
	--
	self.tween_dis_combo = nil

	---- Stam #4
	self.currentstamina = 100
	self.maxstamina = 250
	self.dis_stamina = 100
	--
	self.tween_stamina = nil

	---- Judge #5
	self.dis_opacity_judge = 1
	self.dis_scale_judge = 1
	--
	self.count_perfect = 0
	self.count_great = 0
	self.count_good = 0
	self.count_bad = 0
	self.count_miss = 0
	--
	self.tween1_judge = nil
	self.tween2_judge = nil

	---- Acc #6
	self.totalnote = 0
	self.totalnotescore = 0
	self.acc = 0
	self.dis_acc = 0
	--
	self.tween_dis_acc = nil

	---- Result #7
	self.PUC = true
	self.FC = true
	--
	self.audio_liveclearvoice = nil
	self.audio_livefailvoice = nil
	self.check_liveclearvoiceplayed = false
	self.check_livefailvoiceplayed = false
	--

	---- Other #8
	self.time_live_postend = -math.huge
	self.maj_LCCB = nil
	self.maj_LCCBO = nil
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
	self.comboText = love.graphics.newText(self.fonts[5])
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

	function TRACKLOST.update(_,dt) -- It can be only 3 seconds so :(
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
	if l.ds_cam == 0 and l.ds_srs == 0 then
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
	else
		return 1
	end
end

------------------------------------------------------------
-- Core:Update

function mknui:update(dt,paused)

	if not(paused) then
		self.timer:update(dt)
	end

	if not(l.ds_srs == 1) then
		for i = 8, 1, -1 do
			if self.dis_score >= self.scoreborders[i] then
				if (l.ds_uxs == false) and i > 4 then i = 4 end
				if (l.ds_uxs == true) and (l.ds_esm == 3) and i > 6 then i = 6 end
				
				if not(l.ds_fsne == 1) then
					if self.tween_dis_scorerankcolor then self.timer:cancel(self.tween_dis_scorerankcolor) end
					self.tween_dis_scorerankcolor = self.timer:tween(0.25, self.scorerankcolor, retrieveTheme(1 + i))
				else
					self.scorerankcolor = retrieveTheme(1 + i)
				end

				self.dis_currentrank = scorerank.text[1 + i]
				break
			end
		end
	else
		if self.dis_score >= 9750000 then
			for i = 4, 1, -1 do
				if self.dis_score >= (196 + i) * 50000 then

					if not(l.ds_fsne == 1) then
						if self.tween_dis_scorerankcolor then self.timer:cancel(self.tween_dis_scorerankcolor) end
						self.tween_dis_scorerankcolor = self.timer:tween(0.25, self.scorerankcolor, retrieveTheme(5 + i))
					else
						self.scorerankcolor = retrieveTheme(5 + i)
					end

					self.dis_currentrank = scorerank.text[5 + i]
					break

				end
			end
		elseif self.dis_score >= 9500000 then

			if not(l.ds_fsne == 1) then
				if self.tween_dis_scorerankcolor then self.timer:cancel(self.tween_dis_scorerankcolor) end
				self.tween_dis_scorerankcolor = self.timer:tween(0.25, self.scorerankcolor, retrieveTheme(5))
			else
				self.scorerankcolor = retrieveTheme(5)
			end

			self.dis_currentrank = scorerank.text[5]

		else
			for i = 3, 1, -1 do 
				if self.dis_score >= (6 + i) * 1000000 then

					if not(l.ds_fsne == 1) then
						if self.tween_dis_scorerankcolor then self.timer:cancel(self.tween_dis_scorerankcolor) end
						self.tween_dis_scorerankcolor = self.timer:tween(0.25, self.scorerankcolor, retrieveTheme(1 + i))
					else
						self.scorerankcolor = retrieveTheme(1 + i)
					end

					self.dis_currentrank = scorerank.text[1 + i]
					break

				end
			end
		end
	end

	if self.currentscoreAdd > 0 and not(self.minimalEffect) and not(l.ds_fsne == 1) then
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
				text = love.graphics.newText(self.fonts[7]),
				o = 0, x = 360
			}

			scadd_new.func = function(wait)
				self.timer:tween(0.15, scadd_new, {x = 360 * 1.4, o = 1}, "out-expo")
				wait(0.2)
				self.timer:tween(0.15, scadd_new, {x = 360 * 1.75, o = 0}, "in-quart")
				wait(0.15)
				scadd_new.done = true
			end
		end

		scadd_new.text:clear()
		scadd_new.text:addf(
			{color.white, "+ "..tostring(self.currentscoreAdd)},
			480, "right", -240, self.fonts_hc[5]
		)
		--
		scadd_new.done = false
		scadd_new.o = 0
		scadd_new.x = 360
		scadd_new.ts = self.timer:script(scadd_new.func)

		self.scoreAddEffectList[#self.scoreAddEffectList + 1] = scadd_new
		self.currentscoreAdd = 0
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
	
	if amount == 0 then return end

	self.currentscore = self.currentscore + math.ceil(amount)
	self.currentscore_2 = (self.acc / self.totalnotescore) * 10000000
	--
	self.currentscoreAdd = self.currentscoreAdd + math.ceil(amount)

	if (l.ds_fsne == 1) then
		if (l.ds_srs == 0) then
			self.dis_score = self.currentscore
		else
			self.dis_score = self.currentscore_2
		end
	else
		if self.tween_time_score then
			self.timer:cancel(self.tween_time_score)
			self.tween_time_score = nil
		end

		if (l.ds_srs == 0) then
			self.tween_time_score = self.timer:tween(0.5, self, {dis_score = self.currentscore}, "out-quart")
		else
			self.tween_time_score = self.timer:tween(0.5, self, {dis_score = self.currentscore_2}, "out-quart")
		end
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
		elseif judgement == "great" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Great},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
		elseif judgement == "good" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Good},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.FC = false
			combochoke = true
		elseif judgement == "bad" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Bad},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.FC = false
			combochoke = true
		elseif judgement == "miss" then
			self.judgeText:addf(
				{color.white, self.text.Judge.Miss},
				960, "center", -480, self.fonts_hc[2]
			)
			self.PUC = false
			self.FC = false
			combochoke = true
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

			self.currentcombo = 0

			if judgement == "good" then
				self.acc = self.acc + 0.5
				self.count_good = self.count_good + 1
			elseif judgement == "bad" then
				self.acc = self.acc + 0.25
				self.count_bad = self.count_bad + 1
			elseif judgement == "miss" then
				self.count_miss = self.count_miss + 1
			end

			self.comboText:clear()

		elseif addcombo then
			if (l.ds_adm == 1) then
				self.totalnote = self.totalnote + 1
			end

			self.currentcombo = self.currentcombo + 1
			self.highestcombo = math.max(self.highestcombo, self.currentcombo)

			if judgement == "perfect" then
				self.acc = self.acc + 1
				self.count_perfect = self.count_perfect + 1
			elseif judgement == "great" then
				self.acc = self.acc + 0.75
				self.count_great = self.count_great + 1
			end

			self.comboText:clear()
			self.comboText:addf(
				tostring(self.currentcombo),
				960, "center", -480, self.fonts_hc[1]
			)

		end

		if self.totalnote > 0 then
			if (l.ds_fsne == 1) then
				self.dis_acc = (self.acc/self.totalnote) * 100
			else
				if self.tween_dis_acc then self.timer:cancel(self.tween_dis_acc) end
				self.tween_dis_acc = self.timer:tween(0.5, self, {dis_acc = (self.acc/self.totalnote) * 100}, "out-quart")
			end
		end

		if not(l.ds_fsne == 1) then
			if self.tween1_judge then
				self.timer:cancel(self.tween1_judge)
				self.dis_scale_judge = 1.1
				self.tween1_judge = nil
			end
			self.tween1_judge = self.timer:tween(0.5, self, {dis_scale_judge = 1}, "out-quart")
		end

		if self.tween2_judge then
			self.timer:cancel(self.tween2_judge)
			self.dis_opacity_judge = 1
			self.tween2_judge = nil
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
		self.tween_dis_combo = self.timer:tween(1, self, {dis_opacity_combo = 0}, "in-quart")

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
			some_x = 173

			self.resultText:addf(
				{color.skyBlue, self.text.Result.FC},
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
			self.comboText:clear()

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
	if amount == 0 then return end
	amount = math.ceil(amount)

	self.currentstamina = util.clamp(self.currentstamina + amount, 0, self.maxstamina)

	if (l.ds_fsne == 1) then
		self.dis_stamina = self.currentstamina
	else
		if self.tween_stamina then
			self.timer:cancel(self.tween_stamina)
			self.tween_stamina = nil
		end

		self.tween_stamina = self.timer:tween(0.1, self, {dis_stamina = self.currentstamina}, "out-quart")
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
function mknui:setOpacity(opacity, time, mode)
	if time == nil then time = 1 end
	if opacity == nil then opacity = 1 end
	if mode == nil then mode = "out-quart" end

	if self.tween_dis_opacity then
		self.timer:cancel(self.tween_dis_opacity)
		self.tween_dis_opacity = nil
	end

	if (l.ds_fsne == 1) then
		self.dis_opacity = opacity
	else
		self.tween_dis_opacity = self.timer:tween(time, self, {dis_opacity = opacity}, mode)
	end
end

function mknui:setTextScaling(scale)

end

function mknui:setTotalNotes(tl)
	if l.ds_adm == 2 then
		self.totalnote = tl
	end

	self.totalnotescore = tl
end

function mknui:setMaxStamina(val)
	self.maxstamina = math.min(assert(val > 0 and val, "invalid value"), math.huge)
	self.currentstamina = self.maxstamina
	self.dis_stamina = self.currentstamina
end

function mknui:setComboCheer()

end

function mknui:setLiveClearVoice(voice)
	self.audio_liveclearvoice = voice
end

function mknui:setScoreRange(c, b, a, s)
	self.scoreborders[1],
	self.scoreborders[2],
	self.scoreborders[3],
	self.scoreborders[4],
	self.scoreborders[5],
	self.scoreborders[6],
	self.scoreborders[7],
	self.scoreborders[8] = c, b, a, s, (s*2), (s*3), (s*6), (s*9)
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
	return self:isPauseEnabled() and x >= (468.5 - 12) and y >= 10 and x < (468.5 + 38) and y < 50
end



--------------------
-- Primary Draw Function

function mknui:drawHeader()
	local score_text = tostring(self.text.Top.SCORE.." (Rank "..self.dis_currentrank..")")
	local judge_text = tostring(self.text.Top.JUDGE)
	local acc_text = tostring(self.text.Top.ACC)
	local score_amo = string.format("%07d", self.dis_score)
	local acc_amo = string.format("%.2f", self.dis_acc == 0 and 0 or self.dis_acc).."%"
	local sta_pos = 63
	local auto_pos = 68

	do
		setColor(255, 255, 255, self.dis_opacity * 0.95)
		love.graphics.printf(score_text, self.fonts[1], (l.ds_sbs / 2) - 1, 3, 480, "right", 0)
		if l.ds_dpy == 1 then
			love.graphics.printf(acc_text, self.fonts[1], (480 - (l.ds_sbs / 2)) + 1, 3, 480, "left", 0)
		else
			love.graphics.printf(judge_text, self.fonts[1], (480 - (l.ds_sbs / 2)) + 1, 3, 480, "left", 0)
			---
			love.graphics.printf(self.text.Judge.Perfect, self.fonts[8], (480 - (l.ds_sbs / 2)), 22, 480, "left", 0)
			love.graphics.printf(self.text.Judge.Great, self.fonts[8], (576 - (l.ds_sbs / 2)), 22, 480, "left", 0)
			love.graphics.printf(self.text.Judge.Good, self.fonts[8], (672 - (l.ds_sbs / 2)), 22, 480, "left", 0)
			love.graphics.printf(self.text.Judge.Bad, self.fonts[8], (768 - (l.ds_sbs / 2)), 22, 480, "left", 0)
			love.graphics.printf(self.text.Judge.Miss, self.fonts[8], (864 - (l.ds_sbs / 2)), 22, 480, "left", 0)
		end

		setColor(self.scorerankcolor, self.dis_opacity * 0.9)
		love.graphics.printf(score_amo, self.fonts[2], (l.ds_sbs / 2) - 1, 12, 480, "right", 0)
		if l.ds_dpy == 1 then
			setColor(255, 255, 255, self.dis_opacity * 0.9)
			love.graphics.printf(acc_amo, self.fonts[2], (480 - (l.ds_sbs / 2)) - 1, 12, 480, "left", 0)
		else
			if self.acc > 0 and (self.FC == true) and (self.PUC == true) then
				setColor(255, 215, 0, self.dis_opacity * 0.9)
			elseif self.acc > 0 and (self.FC == true) and (self.PUC == false) then
				setColor(135, 206, 235, self.dis_opacity * 0.9)
			else
				setColor(255, 255, 255, self.dis_opacity * 0.9)
			end
			love.graphics.printf(self.count_perfect, self.fonts[9], (480 - (l.ds_sbs / 2)), 36, 480, "left", 0)
			love.graphics.printf(self.count_great, self.fonts[9], (576 - (l.ds_sbs / 2)), 36, 480, "left", 0)
			love.graphics.printf(self.count_good, self.fonts[9], (672 - (l.ds_sbs / 2)), 36, 480, "left", 0)
			love.graphics.printf(self.count_bad, self.fonts[9], (768 - (l.ds_sbs / 2)), 36, 480, "left", 0)
			love.graphics.printf(self.count_miss, self.fonts[9], (864 - (l.ds_sbs / 2)), 36, 480, "left", 0)
		end

		if not(self.minimalEffect) and not(l.ds_fsne == 1) and not(l.ds_srs == 1) then
			sta_pos = sta_pos + 12
			auto_pos = auto_pos + 4
			local lyne, so_bar

			if (l.ds_uxs == true) and not(l.ds_srs == 1) then
				if l.ds_esm == 1 then
					so_bar = util.clamp(self.dis_score / self.scoreborders[8], 0, 1) * l.ds_sbs
					lyne = {
						ly_C = util.clamp(self.scoreborders[1] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
						ly_B = util.clamp(self.scoreborders[2] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
						ly_A = util.clamp(self.scoreborders[3] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
						ly_S = util.clamp(self.scoreborders[4] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
						ly_SS = util.clamp(self.scoreborders[5] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
						ly_SSS = util.clamp(self.scoreborders[6] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
						ly_SPI = util.clamp(self.scoreborders[7] / self.scoreborders[8], 0, 1) * l.ds_sbs + l.ds_rlo,
					}
				elseif l.ds_esm == 2 then
					if self.dis_score < self.scoreborders[4] then
						so_bar = util.clamp(self.dis_score / self.scoreborders[4], 0, 1) * l.ds_sbs
						lyne = {
							ly_C = util.clamp(self.scoreborders[1] / self.scoreborders[4], 0, 1) * l.ds_sbs + l.ds_rlo,
							ly_B = util.clamp(self.scoreborders[2] / self.scoreborders[4], 0, 1) * l.ds_sbs + l.ds_rlo,
							ly_A = util.clamp(self.scoreborders[3] / self.scoreborders[4], 0, 1) * l.ds_sbs + l.ds_rlo,
						}
					elseif self.dis_score < self.scoreborders[6] then
						so_bar = util.clamp((self.dis_score - self.scoreborders[4]) / (self.scoreborders[6] - self.scoreborders[4]), 0, 1) * l.ds_sbs
						lyne = {
							ly_SS = util.clamp((self.scoreborders[5] - self.scoreborders[4]) / (self.scoreborders[6] - self.scoreborders[4]), 0, 1) * l.ds_sbs + l.ds_rlo,
						}
					else
						so_bar = util.clamp((self.dis_score - self.scoreborders[6]) / (self.scoreborders[8] - self.scoreborders[6]), 0, 1) * l.ds_sbs
						lyne = {
							ly_SPI = util.clamp((self.scoreborders[7] - self.scoreborders[6]) / (self.scoreborders[8] - self.scoreborders[6]), 0, 1) * l.ds_sbs + l.ds_rlo,
						}
					end
				else
					if self.dis_score < self.scoreborders[4] then
						so_bar = util.clamp(self.dis_score / self.scoreborders[4], 0, 1) * l.ds_sbs
						lyne = {
							ly_C = util.clamp(self.scoreborders[1] / self.scoreborders[4], 0, 1) * l.ds_sbs + l.ds_rlo,
							ly_B = util.clamp(self.scoreborders[2] / self.scoreborders[4], 0, 1) * l.ds_sbs + l.ds_rlo,
							ly_A = util.clamp(self.scoreborders[3] / self.scoreborders[4], 0, 1) * l.ds_sbs + l.ds_rlo,
						}
					else
						so_bar = util.clamp((self.dis_score - self.scoreborders[4]) / (self.scoreborders[6] - self.scoreborders[4]), 0, 1) * l.ds_sbs
						lyne = {
							ly_SS = util.clamp((self.scoreborders[5] - self.scoreborders[4]) / (self.scoreborders[6] - self.scoreborders[4]), 0, 1) * l.ds_sbs + l.ds_rlo,
						}
					end
				end
			elseif not(l.ds_srs == 1) then
				so_bar = util.clamp(self.dis_score / self.scoreborders[4], 0, 1) * l.ds_sbs
				lyne = {
					ly_C = (util.clamp(self.scoreborders[1] / self.scoreborders[4], 0, 1) * l.ds_sbs) + l.ds_rlo,
					ly_B = (util.clamp(self.scoreborders[2] / self.scoreborders[4], 0, 1) * l.ds_sbs) + l.ds_rlo,
					ly_A = (util.clamp(self.scoreborders[3] / self.scoreborders[4], 0, 1) * l.ds_sbs) + l.ds_rlo
				}
			end

			setColor(75, 75, 75, self.dis_opacity * 0.5)
			love.graphics.rectangle("fill", ((960 - l.ds_sbs) / 3.5), 63, l.ds_sbs, 4)

			if so_bar ~= nil and so_bar > 0 then
				setColor(self.scorerankcolor, self.dis_opacity * 0.9)
				love.graphics.rectangle("fill", ((960 - l.ds_sbs) / 3.5), 63, so_bar, 4)
			end

			setColor(255,255,255,self.dis_opacity * 0.6)
			love.graphics.setLineWidth(1.05)
			love.graphics.rectangle("line", ((960 - l.ds_sbs) / 3.5), 63, l.ds_sbs, 4)

			if lyne ~= nil and l.ds_sbs == 952 then
				for i,v in pairs(lyne) do
					drawLine("vertical", v, 63, 67)
				end
			end

			for e = #self.scoreAddEffectList, 1, -1 do
				local sael = self.scoreAddEffectList[e]
				if sael.done then break end
				setColor(255, 255, 255, self.dis_opacity * sael.o)
				love.graphics.draw(sael.text, sael.x, 46, 0, 1, 1, 0, 0)
			end

		else
			sta_pos = sta_pos + 8

			setColor(255,255,255,self.dis_opacity * 0.6)
			love.graphics.setLineWidth(1.25)
			drawLine("horizontal", 63, ((960 - l.ds_sbs) / 3.5), l.ds_sbs)
		end

		if (self.staminaFunction) then
			auto_pos = auto_pos + 8

			local bar_color1, bar_color2, sbar_color3, sta_bar
			sta_bar = util.clamp(self.dis_stamina / self.maxstamina, 0, 1) * math.ceil(l.ds_sbs / 3)

			if (self.dis_stamina / self.maxstamina) <= 0.25 then
				bar_color1 = {100, 0, 0, self.dis_opacity * 0.9}
				bar_color2 = {255, 25, 25, self.dis_opacity * 0.8}
			else
				bar_color1 = {25, 25, 25, self.dis_opacity * 0.9}
				bar_color2 = {250, 250, 250, self.dis_opacity * 0.8}
			end

			setColor(bar_color1)
			love.graphics.rectangle("fill", (960 / 3), sta_pos, math.ceil(l.ds_sbs / 3), 4)
			setColor(bar_color2)
			love.graphics.rectangle("fill", (960 / 3), sta_pos, sta_bar, 4)

		end

		if (self.autoplaying) then
			setColor(255, 255, 255, self.dis_opacity * 0.9)
			love.graphics.printf(self.text.Top.AUTO, self.fonts[3], 0, auto_pos, 960, "center", 0)
		end
	end
	

	setColor(255, 255, 255, self.dis_opacity)
	if self.pauseEnabled then
		love.graphics.draw(self.images[1], 468.5, 19, 0, 0.21, 0.21)
	end

end

function mknui:drawStatus()

	if not(self.minimalEffect) and not(l.ds_fsne == 1) then
		for e = #self.tapEffectList, 1, -1 do
			local tel_i = self.tapEffectList[e]
			if tel_i.d then break end

			setColor(tel_i.r, tel_i.g, tel_i.b, tel_i.a * tel_i.o)
			love.graphics.draw(self.images[2], tel_i.x, tel_i.y, 0, tel_i.s, tel_i.s, 64, 64)
		end
	end

	if self.currentcombo > 1 then
		setColor(255, 255, 255, self.dis_opacity * self.dis_opacity_combo * 0.9)
		love.graphics.draw(self.comboText, 480, 427, 0, self.dis_textscaling)
	end

	if self.dis_opacity_judge > 0 then
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