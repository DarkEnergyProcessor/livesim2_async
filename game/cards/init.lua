-- Card definitions, rules, and the team
-- Cards live in "cards/<id>.lua" in the game directory and/or the save directory
-- (save directory wins). Each file returns a table; see cards/README.md.

local love = require("love")
local log = require("logging")
local Setting = require("setting")
local Util = require("util")

local cards = {}

local CARD_DIR = "cards"
local TEAM_SIZE = 9
local VALID_RARITY = {r = true, sr = true, ssr = true, ur = true}

local loadedCards = nil   -- id -> card
local loadedRules = nil

---------------------------------------------------------------------- helpers

-- Files in the save folder's cards/ win over the built-in ones. The game folder
-- is searched first by love.filesystem, so same-named save files are read
-- directly from disk here. (On iPhone they are packaged into the game instead.)
local function readSaveCardFile(file)
	local ok, base = pcall(love.filesystem.getSaveDirectory)
	if not ok or not base or base == "" then return nil end
	local f = io.open(base.."/"..CARD_DIR.."/"..file, "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

local function loadLuaFile(path)
	local chunk, err = love.filesystem.load(path)
	if not chunk then return nil, err end
	local ok, result = pcall(chunk)
	if not ok then return nil, result end
	if type(result) ~= "table" then return nil, "file must return a table" end
	return result
end

local function deepMerge(base, override)
	local out = {}
	for k, v in pairs(base) do out[k] = v end
	for k, v in pairs(override) do
		if type(v) == "table" and type(out[k]) == "table" and #v == 0 and #out[k] == 0 then
			out[k] = deepMerge(out[k], v)
		else
			out[k] = v
		end
	end
	return out
end

local function sanitizeEffect(e, i, id)
	assert(type(e) == "table", string.format("card %s: effect #%d must be a table", id, i))
	assert(type(e.type) == "string", string.format("card %s: effect #%d needs a type", id, i))
	local out = {}
	for k, v in pairs(e) do out[k] = v end
	out.scope = out.scope or "team"
	assert(out.scope == "team" or out.scope == "lane", string.format("card %s: effect scope must be 'team' or 'lane'", id))
	if out.type == "custom" then
		assert(type(out.fn) == "function", string.format("card %s: custom effect needs fn", id))
	end
	return out
end

local function describeTrigger(t)
	if t.key then return "On key notes" end
	if t.start then return "At live start" end
	if t.hp_below then return string.format("When HP drops below %d%%", t.hp_below * 100) end
	for _, k in ipairs({"notes", "combo", "perfect", "great", "good", "bad", "miss", "crit", "lane_notes", "time", "score"}) do
		if t[k] then
			local unit = ({notes = "notes", combo = "combo", perfect = "perfects", great = "greats", good = "goods",
				bad = "bads", miss = "misses", crit = "crits", lane_notes = "notes on this lane", time = "seconds", score = "points"})[k]
			return string.format("Every %d %s", t[k], unit)
		end
	end
	return "?"
end

local function describeEffect(e)
	local dur = e.duration and string.format(" for %gs", e.duration) or ""
	local where = e.scope == "lane" and " (this lane)" or ""
	local pct = function(v) return string.format("%g%%", v * 100) end
	local d = ({
		score = function() return string.format("+%d score", e.value) end,
		score_mult = function() return string.format("score x%g", e.value) end,
		appeal_up = function() return "appeal +"..pct(e.value) end,
		crit_chance_up = function() return "crit chance +"..pct(e.value) end,
		crit_damage_up = function() return "crit damage +"..pct(e.value) end,
		skill_chance_up = function() return "skill chance +"..pct(e.value) end,
		heal = function() return e.fraction and ("heal "..pct(e.fraction)) or string.format("heal %d", e.value) end,
		perfect_lock = function() return "Perfect lock" end,
		perfect_lock_strong = function() return "strong Perfect lock" end,
		guaranteed_crit = function() return string.format("next %d notes crit", e.value) end,
		combo_shield = function() return string.format("%d combo shield", e.value) end,
		custom = function() return e.text or "???" end,
	})[e.type]
	return (d and d() or e.type)..dur..where
end

function cards.describeSkill(skill)
	if not skill then return "No skill" end
	if skill.text then return skill.text end
	local parts = {}
	for _, e in ipairs(skill.effects) do parts[#parts + 1] = describeEffect(e) end
	local chance = skill.trigger.key and "" or string.format(": %d%% chance of ", math.floor(skill.chance * 100 + 0.5))
	if skill.trigger.key then chance = ": " end
	return describeTrigger(skill.trigger)..chance..table.concat(parts, ", ")
end

---------------------------------------------------------------------- rules

function cards.getRules()
	if loadedRules then return loadedRules end
	local rules, err = loadLuaFile(CARD_DIR.."/rules.lua")
	if not rules then
		log.errorf("cards", "cannot load rules.lua: %s", tostring(err))
		rules = {}
	end
	loadedRules = rules
	return rules
end

---------------------------------------------------------------------- cards

local function sanitizeCard(def, id)
	local rules = cards.getRules()
	local c = {}
	c.id = id
	c.name = tostring(def.name or id)
	c.image = def.image and (CARD_DIR.."/"..def.image) or nil
	c.rarity = tostring(def.rarity or "R"):lower()
	if not VALID_RARITY[c.rarity] then c.rarity = "r" end
	c.appeal = tonumber(def.appeal) or 1000
	c.stamina = tonumber(def.stamina) or 1000
	c.tech = tonumber(def.tech) or 1000
	c.critProfile = c.tech > c.appeal
	c.description = def.description
	-- only picks the SIF frame color for UR cards (smile / pure / cool / all)
	c.attribute = def.attribute and tostring(def.attribute):lower() or nil
	-- where to center the circle crop: {x = 0..1, y = 0..1, zoom = >=1}
	if type(def.crop) == "table" then
		c.crop = {x = tonumber(def.crop.x), y = tonumber(def.crop.y), zoom = tonumber(def.crop.zoom)}
	end
	if def.image then
		local bytes = readSaveCardFile(def.image)
		if bytes then
			c.imageData = love.filesystem.newFileData(bytes, def.image)
			c.image = "save:"..def.image
		end
	end

	if def.skill then
		local s = def.skill
		assert(type(s.effects) == "table", string.format("card %s: skill.effects must be a list", id))
		c.skill = {
			text = s.text,
			trigger = s.trigger or rules.defaultTrigger or {notes = 20},
			chance = Util.clamp(tonumber(s.chance) or 1, 0, 1),
			effects = {},
			audio = s.audio,
		}
		for i, e in ipairs(s.effects) do c.skill.effects[i] = sanitizeEffect(e, i, id) end
		c.skill.text = c.skill.text or cards.describeSkill(c.skill)
	end

	c.passives = {}
	for i, e in ipairs(def.passives or {}) do
		local p = sanitizeEffect(e, i, id)
		if e.scope == nil then p.scope = "lane" end
		c.passives[i] = p
	end

	return c
end

---@return table<string, table>
function cards.getAll(reload)
	if loadedCards and not reload then return loadedCards end
	loadedRules = nil
	local list = {}
	local items = love.filesystem.getDirectoryItems(CARD_DIR)
	table.sort(items)
	for _, file in ipairs(items) do
		local id = file:match("^(.+)%.lua$")
		if id and id ~= "rules" then
			local def, err
			local saved = readSaveCardFile(file)
			if saved then
				local chunk, cerr = loadstring(saved, "@"..CARD_DIR.."/"..file)
				if chunk then
					local ok, res = pcall(chunk)
					if ok and type(res) == "table" then def = res else err = ok and "file must return a table" or res end
				else
					err = cerr
				end
			else
				def, err = loadLuaFile(CARD_DIR.."/"..file)
			end
			if def then
				local ok, card = pcall(sanitizeCard, def, id)
				if ok then
					list[id] = card
				else
					log.errorf("cards", "bad card %s: %s", file, tostring(card))
				end
			else
				log.errorf("cards", "cannot load card %s: %s", file, tostring(err))
			end
		end
	end
	loadedCards = list
	return list
end

function cards.get(id)
	return cards.getAll()[id]
end

---@return table[] sorted list of cards
function cards.getSorted()
	local out = {}
	for _, c in pairs(cards.getAll()) do out[#out + 1] = c end
	table.sort(out, function(a, b)
		if a.rarity ~= b.rarity then
			local r = {ur = 1, ssr = 2, sr = 3, r = 4}
			return r[a.rarity] < r[b.rarity]
		end
		return a.name < b.name
	end)
	return out
end

---------------------------------------------------------------------- team

-- A team is 9 card ids; index 1 is the rightmost lane (SIF convention).
function cards.getTeamIds()
	local ids = {}
	for w in tostring(Setting.get("CARD_TEAM") or ""):gmatch("[^\t]+") do
		ids[#ids + 1] = w ~= " " and w or ""
	end
	for i = #ids + 1, TEAM_SIZE do ids[i] = "" end
	return ids
end

function cards.setTeamIds(ids)
	local t = {}
	for i = 1, TEAM_SIZE do t[i] = (ids[i] and ids[i] ~= "") and ids[i] or " " end
	Setting.set("CARD_TEAM", table.concat(t, "\t"))
end

-- Blank card for empty slots
local blank = {
	id = "", name = "(empty)", rarity = "r", appeal = 500, stamina = 500, tech = 0,
	critProfile = false, passives = {}, blank = true
}

---@return table[] 9 cards (blank card for empty slots)
function cards.getTeam()
	local all = cards.getAll()
	local team = {}
	for i, id in ipairs(cards.getTeamIds()) do
		team[i] = all[id] or blank
	end
	return team
end

---------------------------------------------------------------------- key sections

-- keynotes/<beatmap name>.lua returns a list of {start, stop} in seconds (or
-- {start = s, stop = e}); notes within any range are key notes.
function cards.loadKeySections(beatmapName)
	if not beatmapName then return nil end
	local path = "keynotes/"..beatmapName..".lua"
	if not Util.fileExists(path) then return nil end
	local def, err = loadLuaFile(path)
	if not def then
		log.errorf("cards", "bad key section file %s: %s", path, tostring(err))
		return nil
	end
	local out = {}
	for _, r in ipairs(def) do
		local a, b = r.start or r[1], r.stop or r[2]
		if a and b then out[#out + 1] = {math.min(a, b), math.max(a, b)} end
	end
	return out
end

-- Returns the index of the section containing time t, or nil
function cards.isInKeySection(sections, t)
	for i, r in ipairs(sections) do
		if t >= r[1] and t <= r[2] then return i end
	end
	return nil
end

-- Card image, cached (plain newImage: safe to call from anywhere)
local imageCache = {}
function cards.loadImage(card)
	if not (card and card.image) then return nil end
	local img = imageCache[card.image]
	if img == nil then
		if card.imageData or Util.fileExists(card.image) then
			local ok, res = pcall(love.graphics.newImage, card.imageData or card.image, {mipmaps = true})
			img = ok and res or false
			if not ok then log.errorf("cards", "cannot load image %s: %s", card.image, tostring(res)) end
		else
			img = false
		end
		imageCache[card.image] = img
	end
	return img or nil
end

function cards.clearImageCache()
	imageCache = {}
end

cards.TEAM_SIZE = TEAM_SIZE
cards.CARD_DIR = CARD_DIR
cards.describeEffect = describeEffect
cards.describeTrigger = describeTrigger

return cards
