-- SIFTrain beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local bit = require("bit")
local JSON = require("JSON")

local SIFTrain = {
	Name = "SIFTrain Beatmap",
	Extension = "rs"
}

function SIFTrain.Load(file)
	local data = love.filesystem.read(file[1]..".rs")
	local out = {}
	
	if data:sub(1, 3) == "\239\187\191" then
		-- BOM. Useless in here.
		data = data:sub(4)
	end
	
	-- It turns out that SIFTrain uses relaxed Javascript object notation. Damn tons of regex incoming lol
	do
		local music_file_pos = {data:find("music_file", 1, true)}
		
		if #music_file_pos > 0 then
			if data:sub(music_file_pos[1] - 1, music_file_pos[1] - 1) ~= "\"" then
				-- Quote it first
				data = data:gsub("music_file", "\"music_file\"", 1)
			end
			
			if data:find("\"music_file\":\"", 1, true) == nil then
				-- Quote the song file
				data = data:gsub("\"music_file\":([^,]+)", "\"music_file\":\"%1\"")
			end
		end
	end
	
	local sift = JSON:decode(data)
	local notes_data = assert(assert(sift.song_info[1]).notes)
	
	if sift.rank_info then
		local ranks = {}
		local invalid = false
		
		for i = 1, #sift.rank_info do
			local idx = sift.rank_info[i].rank
			ranks[idx - (idx - 3) * 2] = sift.rank_info[i].rank_max
		end
		
		for i = 1, 4 do
			if ranks[i] == nil then
				invalid = true
				break
			end
		end
		
		if not(invalid) then
			ranks[5] = nil
			out.score = ranks
		end
	end
	
	if sift.music_file then
		out.song_file = AquaShine.LoadAudio("audio/"..sift.music_file)
	else
		local bn = AquaShine.Basename(file[1])
		local a, b = bn:match("(.)_(%d+)")
		
		if a and b then
			out.song_file = AquaShine.LoadAudio("audio/"..a.."_"..b..".wav")
		end
	end
	
	if sift.song_info.star and AquaShine.LoadConfig("AUTO_BACKGROUND", 1) == 1 then
		out.background = math.min(sift.song_info.star, 12)
	end
	
	local defattr = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 10)
	local sif_notes = {}
	
	for i = 1, #notes_data do
		local sbm = notes_data[i]
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
	
	table.sort(sif_notes, function(a, b) return a.timing_sec < b.timing_sec end)
	
	out.notes_list = sif_notes
	return out
end

return SIFTrain
