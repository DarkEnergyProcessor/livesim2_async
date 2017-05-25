-- SIFTrain beatmap loader
-- Part of Live Simulator: 2

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
	
	-- Please, this is SIFTrain fault of using non-compilant JSON parser
	if data:find("\"music_file\"") and data:find("\"music_file\":\"") == nil then
		data = data:gsub("\"music_file\":([^,]+)", "\"music_file\":\"%1\"")
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
	end
	
	-- SIFTrain doesn't store attribute information, like LLPractice beatmap
	local defattr = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 10)
	local sif_notes = {}
	
	for i = 1, #notes_data do
		local sbm = notes_data[i]
		local nbm = {}
		
		nbm.timing_sec = sbm.timing_sec
		nbm.notes_attribute = defattr	-- SIFTrain doesn't store attribute information, like LLPractice beatmap
		nbm.notes_level = 1
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
		
		sif_notes[#sif_notes + 1] = nbm
	end
	
	table.sort(sif_notes, function(a, b) return a.timing_sec < b.timing_sec end)
	
	out.notes_list = sif_notes
	return out
end

return SIFTrain
