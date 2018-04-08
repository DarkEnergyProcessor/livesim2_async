-- SIFTrain (Extended) beatmap loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine, NoteLoader = ...
local bit = require("bit")
local SIFTBeatmap = NoteLoader.NoteLoaderNoteObject:extend("NoteLoader.SIFTBeatmap")

----------------------------------
-- SIFTrain Beatmap Note Object --
----------------------------------

function SIFTBeatmap.GetNotesList(this)
	if not(this.notes_list) then
		local sif_notes = {}
		local defattr = AquaShine.LoadConfig("LLP_SIFT_DEFATTR", 10)
		local nd = this.sift.song_info[1].notes
		
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
		
		this.notes_list = sif_notes
		return sif_notes
	end
	
	return this.notes_list
end

function SIFTBeatmap.GetBackgroundID(this, random)
	local i = this.sift.song_info[1]
	local a = math.min(random and i.random_star or i.star, 12)
	if i.member_category == 2 and a < 4 then
		return a + 12
	end
	return a
end

function SIFTBeatmap.GetName(this)
	return this.sift.song_name
end

function SIFTBeatmap.GetBeatmapTypename()
	return "SIFTrain Beatmap"
end

function SIFTBeatmap.GetCoverArt(this)
	if not(this.cover_loaded) and this.sift.live_icon then
		-- Side note: If we try to load image from save directory, always use love.graphics.newImage
		-- This is to ensure that the we can see the changes immediately. AquaShine.LoadImage caches
		-- the image so we won't see the changes immediately if that's used instead.
		local _, img = pcall(love.graphics.newImage, "live_icon/"..this.sift.live_icon, {mipmaps = true})
		
		if _ then
			local covr = {}
			covr.image = img
			covr.title = this.sift.song_name
			
			this.cover = covr
		end
		
		this.cover_loaded = true
	end
	
	return this.cover
end

function SIFTBeatmap.GetScoreInformation(this)
	if not(this.score_loaded) then
		local ranks = {}
		local invalid = false
		
		for i = 1, #this.sift.rank_info do
			local idx = this.sift.rank_info[i].rank
			ranks[idx - (idx - 3) * 2] = this.sift.rank_info[i].rank_max + 1
		end
		
		for i = 1, 4 do
			if ranks[i] == nil then
				invalid = true
				break
			end
		end
		
		if not(invalid) then
			ranks[5] = nil
			this.score = ranks
		end
		
		this.score_loaded = true
	end
	
	return this.score
end

function SIFTBeatmap.GetComboInformation(this)
	if not(this.combo_loaded) and this.sift.combo_info then
		local ranks = {}
		local invalid = false
		
		for i = 1, #this.sift.combo_info do
			local idx = this.sift.combo_info[i].combo
			ranks[idx - (idx - 3) * 2] = this.sift.combo_info[i].combo_max + 1
		end
		
		for i = 1, 4 do
			if ranks[i] == nil then
				invalid = true
				break
			end
		end
		
		if not(invalid) then
			ranks[5] = nil
			this.combo = ranks
		end
		
		this.score_loaded = true
	end
	
	return this.combo
end

function SIFTBeatmap.GetBeatmapAudio(this)
	if this.sift.music_file then
		return AquaShine.LoadAudio("audio/"..this.sift.music_file, false, "decoder")
	else
		local bn = AquaShine.Basename(this.filename)
		local a, b = bn:match("(.)_(%d+)")
		
		if a and b then
			return AquaShine.LoadAudio("audio/"..a.."_"..b..".wav", false, "decoder")
		end
	end
end

function SIFTBeatmap.GetStarDifficultyInfo(this, random)
	return random and this.sift.random_star or this.sift.star or 0
end

return function(json, filename)
	assert(assert(json.song_info[1]).notes)
	local this = SIFTBeatmap()
	
	this.filename = filename
	this.sift = json
	return this
end
