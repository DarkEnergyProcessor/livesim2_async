-- Skill system management
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local Yohane = require("libs.Yohane")

local AssetCache = require("asset_cache")
local AudioManager = require("audio_manager")
local color = require("color")
local log = require("logging")
local Util = require("util")

local note = require("game.live.note")
local liveUIBase = require("game.live.uibase")
local skill = Luaoop.class("Livesim2.Skill")

-- index 1 is skill text (440x139 in 1024x1024 atlas)
-- index 2 is unit skill color (64x64 in 256x256 atlas)
local function skillTextQuad(x, y)
	return love.graphics.newQuad(x * 440, y * 139, 440, 139, 1024, 1024)
end

local function unitSkillColorQuad(x, y)
	return love.graphics.newQuad(x * 64, y * 64, 64, 64, 256, 256)
end
skill.list = {
	score_up = {
		skillTextQuad(0, 1),
		unitSkillColorQuad(2, 1)
	},
	healer = {
		skillTextQuad(1, 1),
		unitSkillColorQuad(3, 1)
	},
	["tw+"] = {
		skillTextQuad(1, 0),
		unitSkillColorQuad(0, 1)
	},
	["tw++"] = {
		skillTextQuad(0, 0),
		unitSkillColorQuad(0, 0)
	}
}

skill.callbackSkill = {
	score_up = function(self, liveUI, _, value)
		liveUI:addScore(value)
		return self:scoreCallback(value)
	end,
	healer = function(_, liveUI, _, value)
		return liveUI:addStamina(value)
	end,
	["tw+"] = function(_, _, noteManager, value)
		return noteManager:setYellowTimingWindow(value)
	end,
	["tw++"] = function(_, _, noteManager, value)
		return noteManager:setRedTimingWindow(value)
	end,
}

skill.rarity = {
	r = "ef_305",
	sr = "ef_306",
	ssr = "ef_308",
	ur = "ef_307"
}

local cutinFlash
local function getFlash()
	if not(cutinFlash) then
		cutinFlash = Yohane.newFlashFromFilename("flash/live_cut_in.flsh")
	end

	return cutinFlash:clone()
end

skill.unitEffectList = {}
local function getSkillUnitEffect()
	for i = 1, #skill.unitEffectList do
		if skill.unitEffectList[i].time <= 0 then
			return skill.unitEffectList[i]
		end
	end

	local a = {
		image = nil,
		time = 0,
		position = 0,
	}
	skill.unitEffectList[#skill.unitEffectList + 1] = a
	return a
end

-- Must be called in async
function skill:__construct(fullNavi, liveUI, noteManager, seed)
	assert(Luaoop.class.is(liveUI, liveUIBase), "bad argument #1 to 'skill' (Livesim2.LiveUI expected)")
	assert(Luaoop.class.is(noteManager, note.manager), "bad argument #2 to 'skill' (Livesim2.NoteManager expected)")

	if not(cutinFlash) then
		getFlash()
	end

	self.liveUIOpacity = 1
	self.rng = love.math.newRandomGenerator(seed[1], seed[2])
	self.fullNavi = fullNavi
	self.liveUI = liveUI
	self.unitPosition = liveUI:getLanePosition()
	self.noteManager = noteManager
	self.images = AssetCache.loadMultipleImages({
		"assets/image/live/skill_text.png",
		"assets/image/live/unit_skill_icon.png"
	}, {mipmaps = true})
	self.flash = nil
	self.skillUnitEffect = {}
	self.skillCondition = {
		notes = {},
		combo = {},
		star = {},
		token = {},
		time = {},
		score = {},
		perfect = {},
		great = {},
		good = {},
		bad = {},
		miss = {},
		crit = {},
		lane_notes = {},
		hp_below = {},
	}
	-- card skills: list of {skill = obj, conditions = {entries...}, card = card, slot = n}
	self.cardSkills = {}
	self.cardLive = nil
	self.hpTriggered = {}
end

local validCondition = {
	"notes", "combo", "star", "token", "time", "score",
	"perfect", "great", "good", "bad", "miss", "crit", "lane_notes"
}

function skill:register(data, condition)
	-- data contains:
	-- type: skill type
	-- chance: skill chance (0..1, number)
	-- rarity: skill rarity effect
	-- value: skill value
	-- unit: unit index
	-- image: big unit image (optional)
	-- audio: skill activation trigger voice (optional)
	log.debugf("skill", "register skill from storyboard, type %s index %d", data.type, data.unit)

	local obj = {
		image = assert(skill.list[data.type], "invalid skill type"),
		chance = Util.clamp(data.chance, 0, 1),
		rarity = assert(skill.rarity[data.rarity:lower()], "invalid skill rarity"),
		callback = skill.callbackSkill[data.type],
		navi = data.image,
		audio = data.audio,
		value = data.value,
		index = assert(self.unitPosition[data.unit], "invalid unit index")
	}

	-- Conditions
	for _, v in ipairs(validCondition) do
		if condition[v] then
			local u = self.skillCondition[v]
			u[#u + 1] = {
				counter = 0,
				needed = condition[v],
				skill = obj
			}
		end
	end
end

function skill:_triggerSkill(v)
	if not(self.flash) then
		self.flash = getFlash()
		if self.fullNavi and v.navi then
			self.flash:setMovie(v.rarity)
			self.flash:setImage("skill_chara", v.navi)
		else
			self.flash:setMovie(skill.rarity.r)
		end
		self.flash:setImage("skill_text", {self.images[1], v.image[1]})

		if v.audio then
			log.debugf("skill", "play skill audio %s", tostring(v.audio))
			AudioManager.stop(v.audio)
			AudioManager.play(v.audio)
		end
	end

	local unitEffect = getSkillUnitEffect()
	unitEffect.image = v.image[2]
	unitEffect.time = 0.7
	unitEffect.index = v.index
	self.skillUnitEffect[#self.skillUnitEffect + 1] = unitEffect

	return v.callback(self, self.liveUI, self.noteManager, v.value)
end

function skill:_handleSkill(v, value)
	v.counter = v.counter + value
	while v.counter >= v.needed do
		v.counter = v.counter - v.needed

		local chance = v.skill.chance
		if v.skill.card and self.cardLive then
			chance = self.cardLive:getSkillChance(chance, v.skill.slot)
		end
		if self.rng:random() < chance then
			log.debugf("skill", "triggering skill with chance %.2f", chance)
			self:_triggerSkill(v.skill)
		end
	end
end

function skill:update(dt, paused)
	if not(paused) then
		for _, v in ipairs(self.skillCondition.time) do
			self:_handleSkill(v, dt)
		end
	end

	if self.flash then
		self.flash:update(dt * 1000)

		if self.flash:isFrozen() then
			self.flash = nil
			log.debugf("skill", "new flash skill ready")
		end
	end

	local length = #self.skillUnitEffect
	local index = 1
	local left = length

	for i = 1, length do
		local x = self.skillUnitEffect[i]
		x.time = x.time - dt

		if x.time <= 0 then
			left = left - 1
		else
			self.skillUnitEffect[index] = x
			index = index + 1
		end
	end

	-- Remove events
	for i = left + 1, length do
		self.skillUnitEffect[i] = nil
	end

	self.liveUIOpacity = self.liveUI:getOpacity()
end

function skill:noteCallback(judgement, token, star, lane)
	assert(Util.isValueInArray(validCondition, judgement), "invalid judgement")

	for _, v in ipairs(self.skillCondition[judgement]) do
		self:_handleSkill(v, 1)
	end

	if lane then
		for _, v in ipairs(self.skillCondition.lane_notes) do
			if v.skill.slot == lane then
				self:_handleSkill(v, 1)
			end
		end
	end

	-- combo-based
	if judgement == "perfect" or judgement == "great" then
		for _, v in ipairs(self.skillCondition.combo) do
			self:_handleSkill(v, 1)
		end

		if token then
			for _, v in ipairs(self.skillCondition.token) do
				self:_handleSkill(v, 1)
			end
		end

		if star then
			for _, v in ipairs(self.skillCondition.star) do
				self:_handleSkill(v, 1)
			end
		end
	else
		-- nullify all combo counter
		for _, v in ipairs(self.skillCondition.combo) do
			v.counter = 0
		end
	end
end

function skill:noteSpawnCallback()
	-- note-based
	for _, v in ipairs(self.skillCondition.notes) do
		self:_handleSkill(v, 1)
	end
end

function skill:scoreCallback(score)
	-- score-based
	for _, v in ipairs(self.skillCondition.score) do
		self:_handleSkill(v, score)
	end
end

function skill:critCallback()
	for _, v in ipairs(self.skillCondition.crit) do
		self:_handleSkill(v, 1)
	end
end

-- fraction: current HP / max HP, called after damage
function skill:hpCallback(fraction)
	for _, v in ipairs(self.skillCondition.hp_below) do
		if fraction < v.needed and not(self.hpTriggered[v]) then
			self.hpTriggered[v] = true
			self:_handleSkill(v, v.needed) -- counter reaches needed exactly once
		end
	end
end

-- Key note: every card skill that is "ready" fires at keyChance, once per key section
function skill:keyNoteCallback(keyChance, section)
	keyChance = keyChance or 1
	section = section or 0
	for _, cs in ipairs(self.cardSkills) do
		if cs.lastKeySection ~= section then
			local ready = cs.key
			if not ready then
				for _, cond in ipairs(cs.conditions) do
					if cond.needed > 0 and cond.counter >= cond.needed * 0.5 then
						ready = true
						cond.counter = 0
					end
				end
			end
			if ready then
				cs.lastKeySection = section
				if self.rng:random() < keyChance then
					log.debugf("skill", "key note fires skill of slot %d", cs.slot)
					self:_triggerSkill(cs.skill)
				end
			end
		end
	end
end

local effectIcon = {
	heal = "healer",
	perfect_lock = "tw+",
	perfect_lock_strong = "tw++",
}

-- Register a card's skill. cardLive is the Livesim2.CardLive instance.
function skill:registerCard(slot, card, cardLive, naviImage)
	self.cardLive = cardLive
	local sk = card.skill
	if not sk then return end

	local icon = "score_up"
	for _, e in ipairs(sk.effects) do
		if effectIcon[e.type] then icon = effectIcon[e.type] break end
	end

	local obj = {
		image = skill.list[icon],
		chance = sk.chance,
		rarity = skill.rarity[card.rarity] or skill.rarity.r,
		callback = function()
			cardLive:applyEffects(sk.effects, slot)
		end,
		navi = naviImage,
		audio = sk.audio,
		value = 0,
		index = assert(self.unitPosition[slot], "invalid slot"),
		card = card,
		slot = slot,
	}

	local entry = {skill = obj, conditions = {}, card = card, slot = slot, key = sk.trigger.key == true}
	self.cardSkills[#self.cardSkills + 1] = entry

	for name, needed in pairs(sk.trigger) do
		if name == "key" or name == "start" then
			-- handled separately
		elseif self.skillCondition[name] then
			local cond = {counter = 0, needed = needed, skill = obj}
			local u = self.skillCondition[name]
			u[#u + 1] = cond
			entry.conditions[#entry.conditions + 1] = cond
		else
			log.warnf("skill", "card %s: unknown trigger %q", card.id, tostring(name))
		end
	end

	if sk.trigger.start then
		entry.startPending = true
	end
end

-- Call once when the live starts (after the countdown)
function skill:liveStartCallback()
	for _, cs in ipairs(self.cardSkills) do
		if cs.startPending then
			cs.startPending = false
			local chance = self.cardLive and self.cardLive:getSkillChance(cs.skill.chance, cs.slot) or cs.skill.chance
			if self.rng:random() < chance then
				self:_triggerSkill(cs.skill)
			end
		end
	end
end

function skill:drawUnder()
	if self.flash then
		self.flash:setOpacity(self.liveUIOpacity * 255)
		self.flash:draw(480, 320)
	end
end

function skill:drawUpper()
	for i = 1, #self.skillUnitEffect do
		local effect = self.skillUnitEffect[i]
		local multipler = effect.time / 0.7
		local scale = (1 - multipler) * 3.8 + 0.2

		love.graphics.setColor(color.compat(255, 255, 255, multipler * self.liveUIOpacity))
		love.graphics.draw(self.images[2], effect.image, effect.index.x, effect.index.y, 0, scale, scale, 32, 32)
	end
end

function skill:triggerDirectly(type, value, unitIndex, rarity, image, audio)
	log.debugf("skill", "direct skill trigger of type %s value %.2f", type, value)

	-- bypassing condition
	return self:_triggerSkill({
		image = assert(skill.list[type], "invalid skill type"),
		rarity = assert(skill.rarity[rarity:lower()], "invalid skill rarity"),
		callback = skill.callbackSkill[type],
		navi = image,
		audio = audio,
		value = value,
		index = assert(self.unitPosition[unitIndex], "invalid unit index")
	})
end

return skill
