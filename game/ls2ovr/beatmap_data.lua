-- LS2OVR beatmap parsing
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local math = require("math")
local Luaoop = require("libs.Luaoop")
local nbt = require("libs.nbt")

local beatmapData = Luaoop.class("LS2OVR.BeatmapData")

local function tryGetBackground(obj)
	local t = obj:getTypeID()

	if t == nbt.TAG_STRING then
		local str = obj:getString()

		if str:sub(1, 1) == ":" then
			return tonumber(obj:sub(2))
		else
			return {
				main = obj,
				left = nil,
				right = nil,
				top = nil,
				bottom = nil
			}
		end
	elseif t == nbt.TAG_COMPOUND then
		local v = obj:getValue()
		local ret = {}

		if v.left and v.right then
			ret.left, ret.right = v.left:getString(), v.right:getString()
		end

		if v.top and v.bottom then
			ret.top, ret.bottom = v.top:getString(), v.bottom:getString()
		end

		if (ret.left and ret.right) or (ret.top and ret.bottom) then
			ret.main = assert(v.main):getString()
			return ret
		else
			return assert(v.main):getString()
		end
	end

	return nil
end

local function getNBTBackground(bg, name)
	local t = type(bg)

	if t == "number" then
		return ":"..bg
	elseif t == "string" then
		return bg
	elseif t == "table" then
		if bg.left == nil and bg.right == nil and bg.top == nil and bg.bottom == nil then
			return assert(bg)
		end

		local retbg = {
			main = bg.main
		}

		if bg.left and bg.right then
			retbg.left, retbg.right = bg.left, bg.right
		end

		if bg.top and bg.bottom then
			retbg.top, retbg.bottom = bg.top, bg.bottom
		end

		return nbt.newCompound(retbg, name)
	end
end

local function sortSIFNote(a, b)
	return a.timing_sec < b.timing_sec
end

function beatmapData:__construct(data)
	self.star = 0
	self.starRandom = 0
	self.difficultyName = ""
	self.background = nil
	self.backgroundRandom = nil
	self.customUnitList = nil
	self.scoreInfo = {0, 0, 0, 0} -- CBAS
	self.comboInfo = {0, 0, 0, 0} -- CBAS
	self.baseScorePerTap = 0
	self.initialStamina = 0
	self.simultaneousFlagProperlyMarked = false
	self.mapData = {} -- SIF beatmap format
	self.editorData = nil -- Software-specific editor data. NBT Compound!

	-- data is full NBT data
	if data then
		self.star = assert(data.star):getInteger()
		self.starRandom = assert(data.starRandom):getInteger()
		self.difficultyName = data.difficultyName and data.difficultyName:getString() or self.star.."\226\152\134"
		self.simultaneousFlagProperlyMarked = data.simultaneousMarked:getInteger() > 0
		self.background = tryGetBackground(data.background)
		self.backgroundRandom = tryGetBackground(data.backgroundRandom)

		if data.customUnitList and #data.customUnitList > 0 then
			self.customUnitList = {}
			for i, v in ipairs(data.customUnitList:getValue()) do
				self.customUnitList[i] = {
					position = assert(v.position):getInteger(),
					filename = assert(v.filename):getString()
				}
			end
		end

		self.baseScorePerTap = data.baseScorePerTap and data.baseScorePerTap:getInteger() or 0
		self.initialStamina = data.stamina and data.stamina:getInteger() or 0

		-- Beatmap data
		for i, v in ipairs(self.map) do
			local b = {}

			-- time
			local t = assert(v.time):getNumber()
			b.timing_sec = assert(t > 0 and t == t and t < math.huge and t)
			-- attribute
			b.notes_attribute = assert(v.attribute):getInteger()
			-- position
			local p = assert(v.position):getInteger()
			b.position = assert(p > 0 and p <= 9 and p)

			-- flags
			local flags = assert(v.flags):getInteger()
			local isSwing = math.floor(flags / 4) % 2 == 1
			local effectMode = flags % 4 + 1

			-- effect
			b.effect = isSwing and 10 + effectMode or effectMode

			-- effect_value
			if effectMode == 3 then
				local l = assert(v.length):getNumber()
				b.effect_value = l > 0 and l == l and l < math.huge and l
			else
				b.effect_value = 2
			end

			-- notes_level
			if isSwing then
				b.notes_level = assert(v.noteGroup):getInteger()
			else
				b.notes_level = 0
			end

			-- Calculate score & combo info
			self.scoreInfo[4] = self.scoreInfo[4] + (isSwing and 370 or 739)
			self.comboInfo[4] = self.comboInfo[4] + 1
			-- put
			self.mapData[i] = b
		end

		-- Score info
		local hasScoreInfo = false
		if data.scoreInfo then
			local v = data.scoreInfo:getValue()
			if #v >= 4 then
				self.scoreInfo[1] = v[1]:getInteger()
				self.scoreInfo[2] = v[2]:getInteger()
				self.scoreInfo[3] = v[3]:getInteger()
				self.scoreInfo[4] = v[4]:getInteger()
				hasScoreInfo = true
			end
		end
		if hasScoreInfo == false then
			self.scoreInfo[1] = math.floor(data.scoreInfo[4] * 211 / 739 + 0.5)
			self.scoreInfo[2] = math.floor(data.scoreInfo[4] * 528 / 739 + 0.5)
			self.scoreInfo[3] = math.floor(data.scoreInfo[4] * 633 / 739 + 0.5)
		end

		-- Combo info
		local hasComboInfo = false
		if data.comboInfo then
			local v = data.comboInfo:getValue()
			if #v >= 4 then
				self.comboInfo[1] = v[1]:getInteger()
				self.comboInfo[2] = v[2]:getInteger()
				self.comboInfo[3] = v[3]:getInteger()
				self.comboInfo[4] = v[4]:getInteger()
				hasComboInfo = true
			end
		end
		if hasComboInfo == false then
			self.comboInfo[1] = math.ceil(data.comboInfo[1] * 0.3)
			self.comboInfo[2] = math.ceil(data.comboInfo[2] * 0.5)
			self.comboInfo[3] = math.ceil(data.comboInfo[3] * 0.7)
		end

		if data.editorData then
			self.editorData = data.editorData
		end
	end
end

function beatmapData:encode()
	local data = {
		star = nbt.newByte(self.star, "star"),
		starRandom = nbt.newByte(self.starRandom, "starRandom"),
		simultaneousMarked = self.simultaneousFlagProperlyMarked and 1 or 0,
	}

	-- Difficulty
	if self.difficultyName and #self.difficultyName > 0 then
		data.difficultyName = self.difficultyName
	end

	-- Background
	if self.background then
		data.background = getNBTBackground(self.background)

		if self.backgroundRandom then
			data.backgroundRandom = getNBTBackground(self.backgroundRandom)
		end
	end

	-- Custom units
	if #self.customUnitList > 0 then
		local cunits = {}

		for i, v in ipairs(self.customUnitList) do
			cunits[i] = nbt.newCompound(v)
		end

		data.customUnitList = nbt.newList(nbt.TAG_COMPOUND, cunits, "customUnitList")
	end

	-- Score info
	if self.scoreInfo and #self.scoreInfo >= 4 then
		data.scoreInfo = nbt.newIntArray({
			self.scoreInfo[1],
			self.scoreInfo[2],
			self.scoreInfo[3],
			self.scoreInfo[4],
		}, "scoreInfo")
	end

	-- Combo info
	if self.comboInfo and #self.comboInfo >= 4 then
		data.comboInfo = nbt.newIntArray({
			self.comboInfo[1],
			self.comboInfo[2],
			self.comboInfo[3],
			self.comboInfo[4],
		}, "comboInfo")
	end

	-- Score/tap
	if self.baseScorePerTap and self.baseScorePerTap > 0 then
		data.baseScorePerTap = nbt.newInt(self.baseScorePerTap, "baseScorePerTap")
	end

	-- Stamina
	if self.initialStamina and self.initialStamina > 0 then
		data.stamina = nbt.newShort(self.initialStamina)
	end

	-- Phase 1: sort and mark simultaneous note
	local simulTab = {}
	table.sort(self.mapData, sortSIFNote)
	for i, v in ipairs(self.mapData) do
		if i > 1 then
			local last = self.mapData[i - 1]
			if math.abs(last.timing_sec - v.timing_sec) <= 0.001 then
				simulTab[i - 1] = true
				simulTab[i] = true
			else
				simulTab[i] = false
			end
		else
			simulTab[i] = false
		end
	end

	-- Phase 2: encode
	local maps = {}
	for i, v in ipairs(self.mapData) do
		local isSwing = v.effect >= 10
		local flags = (v.effect % 10 - 1) % 4
		local isLong = flags == 3
		flags = flags + (isSwing and 4 or 0)
		flags = flags + (simulTab[i] and 8 or 0)

		local ret = {
			time = nbt.newDouble(v.timing_sec, "time"),
			attribute = nbt.newInt(v.notes_attribute, "attribute"),
			position = nbt.newByte(v.position, "position"),
			flags = nbt.newByte(flags, "flags"),
		}

		if isSwing then
			ret.noteGroup = nbt.newInt(v.notes_level, "noteGroup")
		end

		if isLong then
			ret.length = nbt.newDouble(v.effect_value, "length")
		end

		maps[i] = nbt.newCompound(ret)
	end

	-- Phase 3: put
	data.map = nbt.newList(nbt.TAG_COMPOUND, maps, "map")

	-- If there are any editing data
	data.editorData = self.editorData

	return nbt.newCompound(data, "beatmap")
end

return beatmapData
