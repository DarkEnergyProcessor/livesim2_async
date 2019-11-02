-- LS2OVR beatmap parsing
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local math = require("math")
local Luaoop = require("libs.Luaoop")

local beatmapData = Luaoop.class("LS2OVR.BeatmapData")

local function tryGetBackground(obj)
	local t = type(obj)

	if t == "string" then
		if obj:sub(1, 1) == ":" then
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
	elseif t == "table" then
		return obj
	end

	return nil
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

	if data then
		self.star = assert(data.star)
		self.starRandom = assert(data.starRandom)
		self.difficultyName = data.difficultyName or self.star.."\226\152\134"
		self.simultaneousFlagProperlyMarked = not(not(assert(data.simultaneousMarked)))
		self.background = tryGetBackground(data.background)
		self.backgroundRandom = tryGetBackground(data.backgroundRandom)

		if data.customUnitList and #data.customUnitList > 0 then
			self.customUnitList = {}
			for i, v in ipairs(data.customUnitList) do
				self.customUnitList[i] = v
			end
		end

		self.baseScorePerTap = tonumber(data.baseScorePerTap)
		self.initialStamina = data.stamina

		-- Beatmap data
		for i, v in ipairs(self.map) do
			local b = {}

			-- time
			b.timing_sec = assert(v.time > 0 and v.time == v.time and v.time < math.huge and tonumber(v.time))
			-- attribute
			b.notes_attribute = tonumber(v.attribute)
			-- position
			b.position = assert(v.position > 0 and v.position <= 9 and tonumber(v.position))

			-- flags
			local flags = assert(tonumber(v.flags))
			local isSwing = math.floor(flags / 4) % 2 == 1
			local effectMode = flags % 4 + 1

			-- effect
			b.effect = isSwing and 10 + effectMode or effectMode

			-- effect_value
			if effectMode == 3 then
				b.effect_value = v.length > 0 and v.length == v.length and v.length < math.huge and v.length
				b.effect_value = assert(tonumber(b.effect_value))
			else
				b.effect_value = 2
			end

			-- notes_level
			if isSwing then
				b.notes_level = assert(tonumber(v.noteGroup))
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
		if data.scoreInfo and #data.scoreInfo >= 4 then
			self.scoreInfo[1] = data.scoreInfo[1]
			self.scoreInfo[2] = data.scoreInfo[2]
			self.scoreInfo[3] = data.scoreInfo[3]
			self.scoreInfo[4] = data.scoreInfo[4]
		else
			self.scoreInfo[1] = math.floor(data.scoreInfo[4] * 211 / 739 + 0.5)
			self.scoreInfo[2] = math.floor(data.scoreInfo[4] * 528 / 739 + 0.5)
			self.scoreInfo[3] = math.floor(data.scoreInfo[4] * 633 / 739 + 0.5)
		end

		-- Combo info
		if data.comboInfo and #data.comboInfo >= 4 then
			self.comboInfo[1] = data.comboInfo[1]
			self.comboInfo[2] = data.comboInfo[2]
			self.comboInfo[3] = data.comboInfo[3]
			self.comboInfo[4] = data.comboInfo[4]
		else
			self.comboInfo[1] = math.ceil(data.comboInfo[1] * 0.3)
			self.comboInfo[2] = math.ceil(data.comboInfo[2] * 0.5)
			self.comboInfo[3] = math.ceil(data.comboInfo[3] * 0.7)
		end
	end
end

return beatmapData
