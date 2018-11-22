-- Custom Beatmap Festival Beatmap Loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Luaoop = require("libs.Luaoop")
local love = require("love")
local bit = require("bit")
local util = require("util")
local log = require("logging")
local setting = require("setting")
local md5 = require("md5")
local baseLoader = require("game.beatmap.base")

local function imageCache(link)
	return setmetatable({}, {
		__index = function(v, var)
			if link[var] then
				local val = love.image.newImageData(link[var])
				rawset(v, var, val)
				return val
			end

			return nil
		end,
		__mode = "v"
	})
end

local positionTranslate = {L4 = 9, L3 = 8, L2 = 7, L1 = 6, C = 5, R1 = 4, R2 = 3, R3 = 2, R4 = 1}
local cbfUnitIcon = imageCache {
	HONOKA_POOL = "assets/image/cbf/01_pool_unidolized_game_4.png",
	HONOKA_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game_3.png",
	KOTORI_POOL = "assets/image/cbf/01_pool_unidolized_game_3.png",
	KOTORI_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game_2.png",
	MAKI_CIRCUS = "assets/image/cbf/02_circus_unidolized_game.png",
	MAKI_CIRCUS_IDOL = "assets/image/cbf/02_circus_idolized_game.png",
	HANAMARU_SWIMSUIT = "assets/image/cbf/01_Swimsuit_Unidolized_game.png",
	HANAMARU_SWIMSUIT_IDOL = "assets/image/cbf/01_Swimsuit_Idolized_game.png",
	HANAMARU_INITIAL = "assets/image/cbf/01_Initial_Unidolized_game.png",
	HANAMARU_INITIAL_IDOL = "assets/image/cbf/01_Initial_Idolized_game.png",
	ELI_THIEF = "assets/image/cbf/02_thief_unidolized_game.png",
	ELI_THIEF_IDOL = "assets/image/cbf/02_thief_idolized_game.png",
	RIN_ARABIAN = "assets/image/cbf/01_arabianSet_unidolized_game.png",
	RIN_ARABIAN_IDOL = "assets/image/cbf/01_arabianSet_idolized_game.png",
	NOZOMI_IDOLSET = "assets/image/cbf/01_idolCostumeSet_unidolized_game.png",
	NOZOMI_IDOLSET_IDOL = "assets/image/cbf/01_idolCostumeSet_idolized_game.png",
	NICO_DEVIL = "assets/image/cbf/01_devil_unidolized_game.png",
	NICO_DEVIL_IDOL = "assets/image/cbf/01_devil_idolized_game.png",
	UMI_DEVIL = "assets/image/cbf/01_devil_unidolized_game_2.png",
	HANAYO_TAISHOROMAN = "assets/image/cbf/01_taishoRoman_unidolized_game.png",
	HANAYO_TAISHOROMAN_IDOL = "assets/image/cbf/01_taishoRoman_idolized_game.png",
	ELI_POOL = "assets/image/cbf/01_pool_unidolized_game.png",
	KANAN_YUKATA = "assets/image/cbf/01_yukata_unidolized_game.png",
	KANAN_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game.png",
	YOSHIKO_YUKATA = "assets/image/cbf/01_yukata_unidolized_game_2.png",
	YOSHIKO_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game_3.png",
	YOU_YUKATA = "assets/image/cbf/01_yukata_unidolized_game_3.png",
	YOU_YUKATA_IDOL = "assets/image/cbf/01_yukata_idolized_game_2.png",
	MAKI_POOL = "assets/image/cbf/01_pool_unidolized_game_2.png",
	MAKI_POOL_IDOL = "assets/image/cbf/01_pool_idolized_game.png",
	RUBY_GOTHIC = "assets/image/cbf/01_gothic_unidolized_game.png",
	RUBY_GOTHIC_IDOL = "assets/image/cbf/01_gothic_idolized_game.png",
	YOSHIKO_HALLOWEEN = "assets/image/cbf/01_halloween_unidolized_game.png",
	YOSHIKO_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game_2.png",
	MARI_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game.png",
	RIKO_HALLOWEEN_IDOL = "assets/image/cbf/01_halloween_idolized_game_3.png",
	HANAMARU_YUKATA = "assets/image/cbf/02_yukata_unidolized_game.png"
}

local cbfUnitIconFrame = {
	None = {
		UR = imageCache {
			"assets/image/cbf/star4circleUREmpty.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURCustom_Old.png",
			"assets/image/cbf/star4foreURSmile_empty.png"
		},
		SR = imageCache {
			"assets/image/cbf/star4circleSR_Custom.png",
			"assets/image/unit_icon/sr_custom_bg02.png",
		},
		R = imageCache {
			"assets/image/unit_icon/r_custom.png",
			"assets/image/unit_icon/r_custom_bg01.png"
		},
	},
	Smile = {
		UR = imageCache {
			"assets/image/unit_icon/f_UR_1.png",
			"assets/image/cbf/star4foreURSmile.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURSmile_Old.png",
			"assets/image/cbf/star4foreURSmile.png"
		},
		SSR = imageCache {
			"assets/image/unit_icon/f_SSR_1.png",
			"assets/image/unit_icon/b_smile_SR_002.png"
		},
		SR = imageCache {
			"assets/image/unit_icon/f_SR_1.png",
			"assets/image/unit_icon/b_smile_SR_002.png"
		},
	},
	Pure = {
		UR = imageCache {
			"assets/image/unit_icon/f_UR_2.png",
			"assets/image/cbf/star4foreURPure.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURPure_Old.png",
			"assets/image/cbf/star4foreURPure.png"
		},
		SSR = imageCache {
			"assets/image/unit_icon/f_SSR_2.png",
			"assets/image/unit_icon/b_pure_SR_002.png"
		},
		SR = imageCache {
			"assets/image/unit_icon/f_SR_2.png",
			"assets/image/unit_icon/b_pure_SR_002.png"
		},
	},
	Cool = {
		UR = imageCache {
			"assets/image/unit_icon/f_UR_3.png",
			"assets/image/cbf/star4foreURCool.png"
		},
		["UR (Old)"] = imageCache {
			"assets/image/cbf/star4circleURCool_Old.png",
			"assets/image/cbf/star4foreURCool.png"
		},
		SSR = imageCache {
			"assets/image/unit_icon/f_SSR_3.png",
			"assets/image/unit_icon/b_cool_SR_002.png"
		},
		SR = imageCache {
			"assets/image/unit_icon/f_SR_3.png",
			"assets/image/unit_icon/b_cool_SR_002.png"
		},
	},
}

local cbfCompositionThread = Luaoop.class("beatmap.CBF.UnitComposition")

cbfCompositionThread.code = love.filesystem.newFileData([[
local love = require("love")
local div = love._version >= "11.0" and 1 or 1/255
require("love.image")

local dst, astart, aend = ...
local imageCount = (select("#", ...) - 3) / 2

-- a over b method
local function blend(ca, aa, cb, ab)
	return (ca*aa+cb*ab*(1-aa))/(aa+ab*(1-aa))
end

local function clamp(val, min, max)
	return math.max(math.min(val, max), min)
end

local inputs = {}
for i = 1, imageCount do
	local t = {}
	t.image = select(4 + (i - 1) * 2, ...)
	local color = select(4 + (i - 1) * 2 + 1, ...)
	-- for sake of simplicity, use 0..1 range
	t.color = {
		(color[1] or 255) / 255,
		(color[2] or 255) / 255,
		(color[3] or 255) / 255,
		(color[4] or 255) / 255
	}
	inputs[i] = t
end
for i = astart, aend do
	local x = i % 128
	local y = math.floor(i / 128)
	local c = {0, 0, 0, 0}
	-- enum all images
	for _, v in ipairs(inputs) do
		local r, g, b, a = v.image:getPixel(x, y)
		r, g = r * div * v.color[1], g * div * v.color[2]
		b, a = b * div * v.color[3], a * div * v.color[4]
		-- blend
		c[1] = clamp(blend(r, a, c[1], c[4]), 0, 1)
		c[2] = clamp(blend(g, a, c[2], c[4]), 0, 1)
		c[3] = clamp(blend(b, a, c[3], c[4]), 0, 1)
		c[4] = clamp(a + c[4] * (1 - a), 0, 1)
	end
	dst:setPixel(x, y, c[1] / div, c[2] / div, c[3] / div, c[4] / div)
end
]], "cbfCompositionThread")

function cbfCompositionThread:__construct()
	self.threadCount = love.system.getProcessorCount()
	self.dummyImage = love.image.newImageData(1, 1)
end

local function splitIntoParts(whole, parts)
	local arr = {}
	local remain = whole
	local partsLeft = parts

	while partsLeft > 0 do
		local size = math.floor((remain + partsLeft - 1) / partsLeft)
		arr[#arr + 1] = size
		remain = remain - size
		partsLeft = partsLeft - 1
	end

	return arr
end

local white = {255, 255, 255, 255}
function cbfCompositionThread:compose(decl)
	-- decl example:
	-- {ImageData, 255, 255, 255, 255}
	-- ImageData (default to white)
	local dest = love.image.newImageData(128, 128)
	local pushIn = {} -- inputs
	local chunkPerThread = splitIntoParts(128 * 128, self.threadCount)
	local parts = 0
	local threads = {}

	-- create thread
	for i = 1, self.threadCount do
		threads[i] = love.thread.newThread(cbfCompositionThread.code)
	end

	-- push list
	for i = 1, #decl do
		local v = decl[i]

		if type(v) == "table" then
			pushIn[#pushIn + 1] = v[1]
			pushIn[#pushIn + 1] = {v[2] or 255, v[3] or 255, v[4] or 255, v[5] or 255}
		else
			pushIn[#pushIn + 1] = v
			pushIn[#pushIn + 1] = white
		end
	end

	-- Push to thread
	for i = 1, #threads do
		local t = threads[i]

		t:start(dest, parts, parts + chunkPerThread[i] - 1, unpack(pushIn))
		parts = parts + chunkPerThread[i]
	end

	-- synchronize
	for i = 1, #threads do
		threads[i]:wait()
	end

	return dest
end

function cbfCompositionThread:__destruct()
	for i = 1, #self.threads do
		local t = self.threads[i]
		t[2]:push(self.dummyImage)
		log.debug("noteloader.cbf", "killing "..tostring(t[1]))
		t[1]:wait()
	end
end

function cbfCompositionThread.getInstance() end
do
	local inst = cbfCompositionThread()
	function cbfCompositionThread.getInstance()
		return inst
	end
end

------------------------
-- CBF Beatmap Loader --
------------------------

local cbfLoader = Luaoop.class("beatmap.CBF", baseLoader)

function cbfLoader:__construct(path)
	local internal = Luaoop.class.data(self)

	if util.fileExists(path.."projectConfig.txt") and util.fileExists(path.."beatmap.txt") then
		-- load conf
		local conf = {}
		for key, value in love.filesystem.read(path.."projectConfig.txt"):gmatch("%[([^%]]+)%];([^;]+);") do
			conf[key] = tonumber(value) or value
		end

		internal.config = conf
		internal.path = path

		-- check for unit icon loading strategy
		internal.loadUnitMethods = {}
		internal.loadUnitMethods[1] = util.directoryExist(path.."Cards")
		if util.directoryExist(path.."Custom Cards") and util.fileExists(path.."Custom Cards/list.txt") then
			local out = {}

			for line in love.filesystem.lines(path.."Custom Cards/list.txt") do
				if #line > 0 then
					local idx, name = line:match("([^/]+)/([^;]+)")

					if util.fileExists(path.."Custom Cards/"..idx..".png") then
						out[tostring(idx)] = name
					end
				end
			end

			internal.loadUnitMethods[2] = out
		end
	else
		error("directory is not CBF project")
	end
end

function cbfLoader.getFormatName()
	return "Custom Beatmap Festival", "cbf"
end

function cbfLoader:getHash()
	local internal = Luaoop.class.data(self)
	return md5(love.filesystem.newFileData(internal.path.."beatmap.txt"))
end

local function parseNote(str)
	local values = {}
	local curidx = 1
	local nextidx = str:find("/", 1, true)

	while nextidx do
		values[#values + 1] = str:sub(curidx, nextidx - 1)
		curidx = nextidx + 1
		nextidx = str:find("/", curidx, true)
	end

	local lastval = str:sub(curidx)
	if lastval:sub(-1) == ";" then
		lastval = lastval:sub(1, -2)
	end
	values[#values + 1] = lastval

	return unpack(values)
end

function cbfLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	local notesData = {}
	local attribute

	if internal.config.SONG_ATTRIBUTE == "Smile" then
		attribute = 1
	elseif internal.config.SONG_ATTRIBUTE == "Pure" then
		attribute = 2
	elseif internal.config.SONG_ATTRIBUTE == "Cool" then
		attribute = 3
	else
		attribute = setting.get("LLP_SIFT_DEFATTR")
	end

	local readNotesData = {}
	local lineCount = 1
	for line in love.filesystem.lines(internal.path.."beatmap.txt") do
		if #line > 0 then
			readNotesData[#readNotesData + 1] = line
		else
			log.warning("noteloader.cbf", string.format("empty line at line %d ignored", lineCount))
		end

		lineCount = lineCount + 1
	end

	-- sort first
	table.sort(readNotesData, function(a, b)
		return tonumber(a:match("([^/]+)/")) < tonumber(b:match("([^/]+)/"))
	end)

	-- parse (very confusing code)
	local holdNoteQueue = {}
	for _, line in ipairs(readNotesData) do
		local time, pos, _, isHold, isRel, _, _, isStar, colInfo = parseNote(line)
		local r, g, b, isCustomcol = colInfo:match("([^,]+),([^,]+),([^,]+),([True|False]+)")

		if time and pos and isHold and isRel and isStar and r and g and b and isCustomcol then
			local numPos = positionTranslate[pos]
			local attr = attribute
			time = tonumber(time)

			if isCustomcol == "True" then
				-- CBF extension attribute as explained in livesim2 beatmap spec
				attr = bit.bor(
					bit.bor(
						bit.lshift(math.floor(tonumber(r) * 255), 23),
						bit.lshift(math.floor(tonumber(g) * 255), 14)
					),
					bit.bor(bit.lshift(math.floor(tonumber(b) * 255), 5), 31)
				)
			end

			if isRel == "True" then
				local last = assert(holdNoteQueue[numPos], "unbalanced release note")
				last.effect_value = time - last.timing_sec
				holdNoteQueue[numPos] = nil
			elseif isHold == "True" then
				local val = {
					timing_sec = time,
					notes_attribute = attr,
					notes_level = 1,
					effect = 3,
					effect_value = 0,
					position = numPos
				}

				assert(holdNoteQueue[numPos] == nil, "overlapped hold note")
				holdNoteQueue[numPos] = val
				notesData[#notesData + 1] = val
			else
				notesData[#notesData + 1] = {
					timing_sec = time,
					notes_attribute = attr,
					notes_level = 1,
					effect = isStar == "True" and 4 or 1,
					effect_value = 2,
					position = numPos
				}
			end
		else
			log.warning("noteloader.cbf", "ignored: "..line)
		end
	end

	-- sort again
	table.sort(notesData, function(a, b) return a.timing_sec < b.timing_sec end)
	return notesData
end

function cbfLoader:getName()
	local internal = Luaoop.class.data(self)
	return tostring(internal.config.SONG_NAME)
end

local supportedImages = {".png", ".jpg", ".jpeg", ".bmp"}
function cbfLoader:getCoverArt()
	local internal = Luaoop.class.data(self)
	local file = util.substituteExtension(internal.path.."cover", supportedImages)

	if file then
		return {
			title = tostring(internal.config.SONG_NAME),
			info = internal.config.COVER_COMMENT,
			image = love.filesystem.newFileData(file)
		}
	end

	return nil
end

function cbfLoader:getDifficultyString()
	local internal = Luaoop.class.data(self)
	return internal.config.DIFFICULTY_TEMPLATE
end

function cbfLoader:getAudioPathList()
	local internal = Luaoop.class.data(self)
	return {internal.path.."songFile"}
end

local function getUnitByID(id, path, s1, s2)
	id = tostring(id)

	-- Try pre-defined one
	if cbfUnitIcon[id] then
		return cbfUnitIcon[id]
	end

	-- Try stategy 1: look at "Cards" folder for custom cards
	if s1 then
		local a = path.."Cards/"..id..".png"
		if util.fileExists(a) then
			return love.image.newImageData(a)
		end
	end

	-- Try strategy 2: look at "Custom Cards" folder
	if s2 then
		if s2[id] then
			local a = path.."Custom Cards/"..id..".png"
			if util.fileExists(a) then
				return love.image.newImageData(a)
			end
		end
	end

	-- Try current beatmap directory
	local a = path..id..".png"
	if util.fileExists(a) then
		return love.image.newImageData(a)
	end

	-- Try "unit_icon" directory
	a = "unit_icon/"..id..".png"
	if util.fileExists(a) then
		return love.image.newImageData(a)
	end

	-- nope
	return nil
end

-- colors are in 0..255 range
local function composeUnitIcon(unit, colorType, rarity, r, g, b)
	local composition = cbfCompositionThread.getInstance()
	local decl = {}

	if colorType == "Custom" then
		local rarityImage = assert(cbfUnitIconFrame.None[rarity], "invalid rarity")

		decl[#decl + 1] = {rarityImage[2], r, g, b, 255}
		if unit then decl[#decl + 1] = unit end
		decl[#decl + 1] = {rarityImage[1], r, g, b, 255}
	else
		local type = assert(cbfUnitIconFrame[colorType], "invalid color type")
		local rarityImage = assert(type[rarity], "invalid rarity")

		decl[#decl + 1] = rarityImage[2]
		if unit then decl[#decl + 1] = unit end
		decl[#decl + 1] = rarityImage[1]
	end

	return composition:compose(decl)
end

-- implementing this one can be harder
function cbfLoader:getCustomUnitInformation()
	local internal = Luaoop.class.data(self)
	local unitData = {}

	if util.fileExists(internal.path.."characterPositions.txt") then
		local compositionCache = {}

		for line in love.filesystem.lines(internal.path.."characterPositions.txt") do
			local cacheName = line:sub(line:find("/") + 1)
			local p, attr, rar, id, r, g, b = line:match("([^/]+)/([^/]+)/([^/]+)/([^/]*)/(%d+%.?%d*),(%d+%.?%d*),(%d+%.?%d*)/")
			local index = assert(positionTranslate[p])
			local unit = compositionCache[cacheName]

			if not(unit) then
				-- compose
				local unitImage = getUnitByID(id, internal.path, internal.loadUnitMethods[1], internal.loadUnitMethods[2])
				local output = composeUnitIcon(unitImage, attr, rar, r * 255, g * 255, b * 255)

				compositionCache[cacheName] = output
				unit = output
			end

			unitData[index] = unit
		end
	end

	return unitData
end

return cbfLoader, "folder"
