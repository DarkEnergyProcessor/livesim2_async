-- JSON-based beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local bit = require("bit")
local JSON = require("libs.JSON")
local Luaoop = require("libs.Luaoop")
local Setting = require("setting")
local Util = require("util")
local md5 = require("game.md5")
local baseLoader = require("game.beatmap.base")

------------------------
-- SIF beatmap object --
------------------------

local sifLoader = Luaoop.class("beatmap.SIF", baseLoader)

function sifLoader:__construct(bm, hash)
	local internal = Luaoop.class.data(self)
	internal.hash = hash

	if bm.response_data and bm.response_data.live_info then
		bm = bm.response_data

		if bm.live_info then
			-- Captured version
			table.sort(bm.live_info[1].notes_list, function(a, b)
				return a.timing_sec < b.timing_sec
			end)
			internal.notesList = bm.live_info[1].notes_list

			if bm.rank_info then
				table.sort(bm.rank_info, function(a, b) return a.rank > b.rank end)
				internal.score = {
					bm.rank_info[2].rank_min,
					bm.rank_info[3].rank_min,
					bm.rank_info[4].rank_min,
					bm.rank_info[5].rank_min
				}
			end
		end
	elseif #bm > 0 then
		internal.notesList = bm
	else
		error("invalid SIF beatmap")
	end
end

function sifLoader.getFormatName()
	return "SIF Beatmap", "sif"
end

function sifLoader:getHash()
	return assert(Luaoop.class.data(self).hash)
end

function sifLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	return internal.notesList
end

function sifLoader:getScoreInformation()
	local internal = Luaoop.class.data(self)
	return internal.score
end

function sifLoader:getComboInformation()
	local internal = Luaoop.class.data(self)
	local total = #internal.notesList

	return {
		math.ceil(total * 0.3),
		math.ceil(total * 0.5),
		math.ceil(total * 0.7),
		total
	}
end

-----------------------------
-- SIFTrain beatmap object --
-----------------------------

local siftLoader = Luaoop.class("beatmap.SIFTrain", baseLoader)

function siftLoader:__construct(bm, file, hash)
	local i = Luaoop.class.data(self)
	i.hash = hash
	i.data = bm
	i.filename = Util.basename(file:getFilename())
end

function siftLoader.getFormatName()
	return "SIFTrain Beatmap", "sift"
end

function siftLoader:getHash()
	return assert(Luaoop.class.data(self).hash)
end

function siftLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	local sif_notes = {}
	local defattr = Setting.get("LLP_SIFT_DEFATTR")
	local nd = internal.data.song_info[1].notes

	for i = 1, #nd do
		local sbm = nd[i]
		local nbm = {}

		nbm.timing_sec = sbm.timing_sec
		nbm.notes_attribute = sbm.notes_attribute or defattr
		nbm.notes_level = sbm.notes_level or 1
		nbm.effect = 1
		nbm.effect_value = sbm.effect_value
		nbm.position = sbm.position

		-- Determine effect
		if bit.band(sbm.effect, 2) > 0 then
			-- Token note
			nbm.effect = 2
		elseif bit.band(sbm.effect, 4) > 0 then
			-- Long note
			nbm.effect = 3
		elseif bit.band(sbm.effect, 8) > 0 then
			-- Star note
			nbm.effect = 4
		end

		if bit.band(sbm.effect, 32) > 0 then
			-- Swing note
			nbm.effect = nbm.effect + 10
		end

		if nbm.effect > 13 then
			nbm.effect = 11
		end

		sif_notes[#sif_notes + 1] = nbm
	end

	return sif_notes
end

function siftLoader:getName()
	local internal = Luaoop.class.data(self)
	return internal.data.song_name
end

function siftLoader:getCoverArt()
	local internal = Luaoop.class.data(self)

	if internal.data.live_icon and Util.fileExists("live_icon/"..internal.data.live_icon) then
		-- Can't use love.graphics.newImage here
		local s, img = pcall(love.image.newImageData, "live_icon/"..internal.data.live_icon)

		if s then
			return {
				image = img,
				title = internal.data.song_name
			}
		end
	end
end

function siftLoader:getScoreInformation()
	local internal = Luaoop.class.data(self)
	local ranks = {}
	local invalid = false

	for i = 1, #internal.data.rank_info do
		local idx = internal.data.rank_info[i].rank
		ranks[idx - (idx - 3) * 2] = internal.data.rank_info[i].rank_max + 1
	end

	for i = 1, 4 do
		if ranks[i] == nil then
			invalid = true
			break
		end
	end

	if not(invalid) then
		ranks[5] = nil
		return ranks
	end

	return nil
end

function siftLoader:getComboInformation()
	local internal = Luaoop.class.data(self)
	local ranks = {}
	local invalid = false

	for i = 1, #internal.data.combo_info do
		local idx = internal.data.combo_info[i].combo
		ranks[idx - (idx - 3) * 2] = internal.data.combo_info[i].combo_max + 1
	end

	for i = 1, 4 do
		if ranks[i] == nil then
			invalid = true
			break
		end
	end

	if not(invalid) then
		ranks[5] = nil
		return ranks
	end

	return nil
end

function siftLoader:getStarDifficultyInfo()
	local internal = Luaoop.class.data(self)
	local s = internal.data.star or 0
	local rs = internal.data.random_star or 0

	if s ~= rs then return s, rs
	else return s end
end

function siftLoader:getAudioPathList()
	local internal = Luaoop.class.data(self)
	local paths = {}

	local s, e = internal.filename:match("(.)_(%d+)")
	if s and e then
		paths[#paths + 1] = "audio/"..s.."_"..e
	end

	if internal.data.music_file then
		local a = internal.data.music_file
		paths[#paths + 1] = "audio/"..a:sub(1, #a - (a:reverse():find(".", 1, true) or 0))
	end

	return paths
end

local diffString = {
	"Easy", "Normal", "Hard", "Expert"
}
function siftLoader:getDifficultyString()
	local internal = Luaoop.class.data(self)
	if internal.data.difficulty then
		return diffString[internal.data.difficulty] or string.format("Number %d", internal.data.difficulty)
	end
end

------------------------
-- LLP Beatmap Loader --
------------------------

local llpLoader = Luaoop.class("beatmap.LLP", baseLoader)

function llpLoader:__construct(bm, hash)
	local internal = Luaoop.class.data(self)
	internal.hash = hash
	internal.llp = bm
end

function llpLoader.getFormatName()
	return "LLPractice Beatmap", "llp"
end

function llpLoader:getHash()
	return assert(Luaoop.class.data(self).hash)
end

function llpLoader:getNotesList()
	local internal = Luaoop.class.data(self)
	local attribute = Setting.get("LLP_SIFT_DEFATTR")
	local sifMap = {}

	for _, v in ipairs(internal.llp.lane) do
		for _, b in ipairs(v) do
			local newEffect = 1
			local newEffectVal = 2

			if b.longnote then
				newEffect = 3
				newEffectVal = (b.endtime - b.starttime) / 1000
			end

			sifMap[#sifMap + 1] = {
				timing_sec = b.starttime / 1000,
				notes_attribute = attribute or 1,
				notes_level = 1,
				effect = newEffect,
				effect_value = newEffectVal,
				position = 9 - b.lane
			}
		end
	end

	table.sort(sifMap, function(a, b) return a.timing_sec < b.timing_sec end)
	return sifMap
end

function llpLoader:getAudioPathList()
	local internal = Luaoop.class.data(self)
	local t = {nil}
	if internal.llp.audiofile then
		t[1] = "audio/"..internal.llp.audiofile
	end
	return t
end

-------------------------
-- SIF2 Beatmap Loader --
-------------------------

---@class Livesim2.Beatmap.SIF2
local SIF2Loader = Luaoop.class("beatmap.SIF2", baseLoader)

---@param bm table
function SIF2Loader:__construct(bm, hash)
	assert(bm.m_NoteList, "not SIF2 beatmap")

	local internal = Luaoop.class.data(self)
	internal.hash = hash
	internal.notes = SIF2Loader.convert(bm.m_NoteList)

	if bm.m_SoundName then
		internal.songName = Util.removeExtension(bm.m_SoundName)
	end
end

---@param notesList table[]
function SIF2Loader.convert(notesList)
	-- SIF2 beatmap is a parent/child for swing and long note.

	local result = {}
	-- SIF2 doesn't expose the attribute. Use default!
	local attribute = Setting.get("LLP_SIFT_DEFATTR")

	-- Stores notes_level for parent swing note.
	---@type table<number, number?>
	local swingMap = {}
	-- Stores converted beatmap for specific SIF2 `m_Id` beatmap.
	---@type table<number, table>
	local resultMap = {}
	local notesLevelId = 2

	for _, v in ipairs(notesList) do
		if v.m_Type ~= 0 then
			local add = true
			local map = {
				timing_sec = v.m_Time,
				notes_attribute = attribute + 0,
				notes_level = 1,
				effect = 0,
				effect_value = 1,
				-- m_Line starts from 0
				position = v.m_Line + 1
			}

			if v.m_Type == 1 then
				if v.m_ParentId ~= 0 then
					-- Is it long note or swing (long) note?
					local parentBeatmap = resultMap[v.m_ParentId]
					local parentNotesLevel = swingMap[v.m_ParentId]

					if parentBeatmap.position == v.m_Line + 1 then
						-- This is child of a long note.
						parentBeatmap.effect = 3
						parentBeatmap.effect_value = v.m_Time - parentBeatmap.timing_sec

						if parentNotesLevel then
							parentBeatmap.effect = 13
							parentBeatmap.notes_level = parentNotesLevel
						end

						add = false
					else
						-- This is child of a swing note.
						-- Set so we only need to lookup once (eliminates `while` loop)
						swingMap[v.m_Id] = parentNotesLevel
						map.notes_level = parentNotesLevel
						map.effect = 11
					end
				elseif v.m_ChildId ~= 0 and v.m_ChildLine ~= v.m_Line then
					-- This is parent of a swing note.
					map.notes_level = notesLevelId
					map.effect = 11
					swingMap[v.m_Id] = notesLevelId
					-- Increment notes level
					notesLevelId = notesLevelId + 1
				else
					-- This is regular note
					map.effect = 1
				end
			end

			if add then
				result[#result + 1] = map
				resultMap[v.m_Id] = map
			end
		end
	end

	return result
end

function SIF2Loader.getFormatName()
	return "SIF2 Beatmap", "sif2"
end

function SIF2Loader:getHash()
	return assert(Luaoop.class.data(self).hash)
end

function SIF2Loader:getNotesList()
	local internal = Luaoop.class.data(self)
	return internal.notes
end

function SIF2Loader:getAudioPathList()
	local internal = Luaoop.class.data(self)
	local paths = {}

	if internal.songName then
		paths[#paths + 1] = "audio/"..internal.songName
	end

	return paths
end

---@param f love.File
return function(f)
	-- f is File object, beatmap.thread guarantee that the
	-- read position is always at position 0
	local firstdata = f:read(30)
	local hasBOM = false
	-- Skip UTF-8 BOM uh
	if firstdata:find("\239\187\191", 1, true) then
		firstdata = firstdata:sub(4)
		hasBOM = true
	end

	assert(firstdata:find("%s*[{|%[]"), "invalid JSON")

	local data = firstdata..f:read()
	local s, bm = pcall(JSON.decode, JSON, data)
	assert(s and bm, "failed to decode JSON")
	local hash = md5(data)

	if
		bm.song_info and
		bm.song_info[1] and
		bm.song_info[1].notes and
		bm.rank_info and
		bm.song_name
	then
		-- SIFTrain
		local x = siftLoader(bm, f, hash)
		f:close()
		return x
	elseif bm.lane and bm.audiofile then
		-- LLP
		f:close()
		return llpLoader(bm, hash)
	elseif bm.m_NoteList then
		-- SIF2
		return SIF2Loader(bm, hash)
	else
		-- SIF
		f:close()
		return sifLoader(bm, hash)
	end
end, "file"
