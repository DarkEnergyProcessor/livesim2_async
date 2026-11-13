-- Live-time card state: modifiers, per-note scoring, crits, HP, skill effects.
-- Created once per live show by game/states/livesim2.lua.

local love = require("love")
local Luaoop = require("libs.Luaoop")
local log = require("logging")

local cards = require("game.cards")

---@class Livesim2.CardLive
local CardLive = Luaoop.class("Livesim2.CardLive")

local JUDGE_RANK = {perfect = 5, great = 4, good = 3, bad = 2, miss = 1}

function CardLive:__construct(team, seed)
	self.team = team
	self.rules = cards.getRules()
	self.rng = love.math.newRandomGenerator(seed and seed[1] or os.time(), seed and seed[2] or 0)
	self.time = 0
	self.modifiers = {}      -- {type, value, scope, slot, expires, count}
	self.liveUI = nil        -- set by livesim2 after liveUI exists
	self.skill = nil         -- skill engine, set by livesim2
	self.noteManager = nil
	-- per-lane stats are indexed by team slot (1 = rightmost lane)
	self.stats = {crits = 0, skillFires = 0, laneScore = {}, laneCrits = {}, laneSkills = {}, laneNotes = {}}
	for i = 1, 9 do
		self.stats.laneScore[i], self.stats.laneCrits[i] = 0, 0
		self.stats.laneSkills[i], self.stats.laneNotes[i] = 0, 0
	end

	-- HP
	local total = 0
	for _, c in ipairs(team) do total = total + c.stamina end
	self.maxHP = math.max(1, math.floor(total * (self.rules.staminaScale or 1)))
	self.hp = self.maxHP
	-- The live UIs show HP as a 0..99 bar; real HP is tracked here and mirrored
	self.displayMax = 99
	self.displayHP = self.displayMax

	-- passives are permanent modifiers
	for slot, c in ipairs(team) do
		for _, p in ipairs(c.passives or {}) do
			self:applyEffect(p, slot, true)
		end
	end
end

function CardLive:setSeed(seed)
	self.rng = love.math.newRandomGenerator(seed[1], seed[2])
end

function CardLive:attach(liveUI, noteManager, skill)
	self.liveUI = liveUI
	self.noteManager = noteManager
	self.skill = skill
end

function CardLive:getTeam() return self.team end
function CardLive:getCard(slot) return self.team[slot] end
function CardLive:getMaxHP() return self.maxHP end

---------------------------------------------------------------- modifiers

-- Sum of active modifier values of a type that apply to a slot
function CardLive:getMod(mtype, slot)
	local total = 0
	for _, m in ipairs(self.modifiers) do
		if m.type == mtype and (m.scope == "team" or m.slot == slot) then
			total = total + (m.value or 0)
		end
	end
	return total
end

-- Product of (value) for multiplicative modifiers
function CardLive:getMult(mtype, slot)
	local total = 1
	for _, m in ipairs(self.modifiers) do
		if m.type == mtype and (m.scope == "team" or m.slot == slot) then
			total = total * (m.value or 1)
		end
	end
	return total
end

function CardLive:hasMod(mtype, slot)
	for _, m in ipairs(self.modifiers) do
		if m.type == mtype and (m.scope == "team" or m.slot == slot) then return true end
	end
	return false
end

-- Find a counted modifier (guaranteed_crit, combo_shield) that applies and use one charge
function CardLive:consumeCounted(mtype, slot)
	for i, m in ipairs(self.modifiers) do
		if m.type == mtype and (m.scope == "team" or m.slot == slot) and m.count and m.count > 0 then
			m.count = m.count - 1
			if m.count <= 0 then table.remove(self.modifiers, i) end
			return true
		end
	end
	return false
end

-- A timed modifier from the same card effect refreshes instead of stacking
function CardLive:addModifier(m)
	m.scope = m.scope or "team"
	if m.duration then m.expires = self.time + m.duration end
	if m.source then
		for i, old in ipairs(self.modifiers) do
			if old.source == m.source then
				if m.count and old.count then m.count = math.max(m.count, old.count) end
				self.modifiers[i] = m
				return m
			end
		end
	end
	self.modifiers[#self.modifiers + 1] = m
	return m
end

function CardLive:update(dt, paused)
	if paused then return end
	self.time = self.time + dt
	local n = #self.modifiers
	local j = 1
	for i = 1, n do
		local m = self.modifiers[i]
		if not (m.expires and self.time >= m.expires) then
			self.modifiers[j] = m
			j = j + 1
		end
	end
	for i = j, n do self.modifiers[i] = nil end
end

---------------------------------------------------------------- effects

function CardLive:addScore(amount)
	if self.liveUI and amount ~= 0 then self.liveUI:addScore(math.floor(amount)) end
end

-- Change real HP by delta and mirror it to the UI bar
function CardLive:changeHP(delta)
	self.hp = math.max(0, math.min(self.maxHP, self.hp + delta))
	local shown = math.floor(self.hp / self.maxHP * self.displayMax + 0.5)
	if self.hp > 0 then shown = math.max(1, shown) end
	if shown ~= self.displayHP then
		if self.liveUI then self.liveUI:addStamina(shown - self.displayHP) end
		self.displayHP = shown
	end
	return self.hp
end

function CardLive:heal(amount)
	if amount > 0 then self:changeHP(math.floor(amount)) end
end

function CardLive:damage(amount)
	if amount > 0 then self:changeHP(-math.floor(amount)) end
	return self.hp
end

function CardLive:getHP() return self.hp end
function CardLive:getHPFraction() return self.hp / self.maxHP end

-- Apply one effect for the card in `slot`. `permanent` = passive (no expiry).
function CardLive:applyEffect(e, slot, permanent, source)
	local t = e.type
	local scope = e.scope or "team"
	local dur = (not permanent) and e.duration or nil
	local lane = scope == "lane" and slot or nil
	source = (not permanent) and source or nil

	if t == "score" then
		self:addScore(e.value or 0)
		if self.stats.laneScore[slot] then
			self.stats.laneScore[slot] = self.stats.laneScore[slot] + math.floor(e.value or 0)
		end
	elseif t == "heal" then
		local amount = e.fraction and (e.fraction * self.maxHP) or (e.value or 0)
		self:heal(amount)
	elseif t == "score_mult" or t == "appeal_up" or t == "crit_chance_up" or t == "crit_damage_up"
		or t == "skill_chance_up" or t == "perfect_lock" or t == "perfect_lock_strong" then
		self:addModifier({type = t, value = e.value, scope = scope, slot = lane, duration = dur, source = source})
	elseif t == "guaranteed_crit" or t == "combo_shield" then
		self:addModifier({type = t, count = e.value or 1, scope = scope, slot = lane, duration = dur, source = source})
	elseif t == "custom" then
		local ok, err = pcall(e.fn, self, self.team[slot], slot)
		if not ok then log.errorf("cards", "custom effect error (slot %d): %s", slot, tostring(err)) end
	else
		log.warnf("cards", "unknown effect type %q", tostring(t))
	end
end

function CardLive:applyEffects(effects, slot)
	self.stats.skillFires = self.stats.skillFires + 1
	if self.stats.laneSkills[slot] then
		self.stats.laneSkills[slot] = self.stats.laneSkills[slot] + 1
	end
	for i, e in ipairs(effects) do self:applyEffect(e, slot, false, slot.."/"..i) end
end

-- Copy of the per-song stats for the results screen
function CardLive:getStats()
	local out = {crits = self.stats.crits, skillFires = self.stats.skillFires}
	for _, k in ipairs({"laneScore", "laneCrits", "laneSkills", "laneNotes"}) do
		out[k] = {}
		for i = 1, 9 do out[k][i] = self.stats[k][i] or 0 end
	end
	out.team = {}
	for i = 1, 9 do out.team[i] = self.team[i] end
	return out
end

-- Activation chance for a card's skill, after modifiers
function CardLive:getSkillChance(base, slot)
	return math.min(1, math.max(0, base + self:getMod("skill_chance_up", slot)))
end

---------------------------------------------------------------- scoring

function CardLive:getComboBonus(combo)
	local tiers = self.rules.comboBonus or {{0, 1}}
	local mult = 1
	for _, tier in ipairs(tiers) do
		if combo >= tier[1] then mult = tier[2] end
	end
	return mult
end

function CardLive:getCritChance(slot)
	local c = self.team[slot]
	local r = self.rules
	local chance = c.tech * (r.techToCritChance or 0)
	if c.critProfile then chance = chance + (r.critProfileBonus or 0) end
	chance = chance + self:getMod("crit_chance_up", slot)
	return math.min(r.maxCritChance or 1, math.max(0, chance))
end

-- Upgrade a judgement according to perfect locks / combo shield.
-- Returns the judgement to use for combo and scoring.
function CardLive:adjustJudgement(judgement, slot)
	if judgement == "great" and self:hasMod("perfect_lock", slot) then return "perfect" end
	if (judgement == "great" or judgement == "good") and self:hasMod("perfect_lock_strong", slot) then return "perfect" end
	if JUDGE_RANK[judgement] <= JUDGE_RANK.good and self:consumeCounted("combo_shield", slot) then
		-- shield keeps the combo alive; score as a great
		return "great"
	end
	return judgement
end

---@param slot number lane index (1 = rightmost)
---@param judgement string already adjusted
---@param combo number combo before this note
---@param flags table {release=bool, swing=bool}
---@return number score, boolean crit
function CardLive:noteScore(slot, judgement, combo, flags)
	local r = self.rules
	local c = self.team[slot]
	local j = (r.judgement or {})[judgement] or 0
	if j <= 0 then return 0, false end

	local appeal = c.appeal * (1 + self:getMod("appeal_up", slot))
	local base = appeal * (r.appealScale or 1) * j
	base = base * self:getComboBonus(combo)
	if flags and flags.release then base = base * (r.holdBonus or 1) end
	if flags and flags.swing then base = base * (r.swingPenalty or 1) end

	local crit = false
	if self:consumeCounted("guaranteed_crit", slot) or self.rng:random() < self:getCritChance(slot) then
		crit = true
		base = base * ((r.critMultiplier or 1.5) + self:getMod("crit_damage_up", slot))
		self.stats.crits = self.stats.crits + 1
		self.stats.laneCrits[slot] = (self.stats.laneCrits[slot] or 0) + 1
	end

	base = math.ceil(base * self:getMult("score_mult", slot))
	self.stats.laneScore[slot] = (self.stats.laneScore[slot] or 0) + base
	self.stats.laneNotes[slot] = (self.stats.laneNotes[slot] or 0) + 1
	return base, crit
end

function CardLive:getDamage(judgement, star)
	local frac = (self.rules.damage or {})[judgement] or 0
	if star then frac = frac * (self.rules.starDamageMultiplier or 1) end
	return math.floor(self.maxHP * frac)
end

return CardLive
