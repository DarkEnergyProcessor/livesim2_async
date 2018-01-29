-- Beatmap information UI (download)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local BeatmapInfoDL = AquaShine.Node:extend("Livesim2.BeatmapInfoDL")
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local CoverArtLoading = AquaShine.LoadModule("external.cover_art_loading")

function BeatmapInfoDL.init(this, beatmap_data, NoteLoader)
	AquaShine.Node.init(this)
	this.infofont = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	this.arrangementfont = AquaShine.LoadFont("MTLmr3m.ttf", 16)
	this.layoutimage = AquaShine.LoadImage("assets/image/ui/com_win_40.png")
	
	-- Title text
	this.child[1] = TextShadow(AquaShine.LoadFont("MTLmr3m.ttf", 30), "", 64, 560)
		:setShadow(1, 1, true)
	-- OK button
	this.child[2] = SimpleButton(
		AquaShine.LoadImage("assets/image/ui/com_button_14.png"),
		AquaShine.LoadImage("assets/image/ui/com_button_14se.png"),
		function()
			-- TODO
		end
	)
		:setPosition(768, 529)
		:setDisabledImage(AquaShine.LoadImage("assets/image/ui/com_button_14di.png"))
		:disable()
	this.child[3] = CoverArtLoading()
		:setPosition(440, 130)
	
end

function BeatmapInfoDL.setBeatmapData(this, beatmap)
	local mapdata = {}
	-- At least, mapdata must contain these fields:
	-- * data - The beatmap data, if it's NoteLoaderNoteObject (optional)
	-- * name - Beatmap name
	-- * score_info - String-formatted score info (optional)
	-- * combo_info - String-formatted combo info (optional)
	-- * type - Beatmap format type
	-- * difficulty - Beatmap difficulty string (optional)
	-- * cover - Beatmap cover which contains "image" field, optionally with "arrangement" field too. (optional)
	-- * song - Beatmap song file (optional)
	
	if beatmap then this.child[2]:enable() else this.child[2]:disable() end
	
	if beatmap.__name and beatmap.__name:find("NoteLoader.", 1, true) == 1 then
		-- We received beatmap of type NoteLoader object
		mapdata.data = beatmap
		
		-- Beatmap name
		mapdata.name = beatmap:GetName()
		
		-- Beatmap type
		mapdata.type = beatmap:GetBeatmapTypename()
		
		-- Score information
		local si = beatmap:GetScoreInformation()
		if si then
			mapdata.score_info = string.format("%d\n%d\n%d\n%d", si[4], si[3], si[2], si[1])
		end
		
		-- Combo information
		local ci = beatmap:GetComboInformation()
		if ci then
			mapdata.combo_info = string.format("%d\n%d\n%d\n%d", ci[4], ci[3], ci[2], ci[1])
		end
		
		-- Difficulty information
		local din = beatmap:GetStarDifficultyInfo()
		if din > 0 then
			local dir = beatmap:GetStarDifficultyInfo(true)
			
			if dir ~= din then
				mapdata.difficulty = string.format("%d\226\152\134 (Random %d\226\152\134)", din, dir)
			else
				mapdata.difficulty = string.format("%d\226\152\134", din)
			end
		end
		
		-- Song file
		local sounddata = beatmap:GetBeatmapAudio()
		if sounddata then
			mapdata.song = love.audio.newSource(sounddata)
			this.child[3]:enable()
		end
		
		-- Cover art
		mapdata.cover = beatmap:GetCoverArt()
	else
		-- Well, it's in NCache format
		mapdata.filename = beatmap.filename
		mapdata.name = beatmap.name
		mapdata.type = beatmap.type
		mapdata.difficulty = beatmap.difficulty
		
		-- Score information
		local si = beatmap.score_data
		mapdata.score_info = string.format("%d\n%d\n%d\n%d", si[4], si[3], si[2], si[1])
		
		-- Combo information
		local ci = beatmap.combo_data
		mapdata.combo_info = string.format("%d\n%d\n%d\n%d", ci[4], ci[3], ci[2], ci[1])
		
		-- Cover art
		mapdata.cover = beatmap.cover_art
	end
	
	this.userdata.beatmap = mapdata
end

function BeatmapInfoDL.draw(this)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(this.layoutimage, 420, 110, 0, 0.85, 0.85)
	love.graphics.rectangle("fill", 440, 130, 160, 160)
	love.graphics.setColor(0, 0, 0)
	love.graphics.setFont(this.infofont)
	love.graphics.print("Score", 620, 132)
	love.graphics.print("Combo", 800, 132)
	love.graphics.print("S\nA\nB\nC", 604, 152)
	love.graphics.print("Beatmap Type:", 440, 330)
	love.graphics.print("Difficulty:", 440, 380)
	
	if this.userdata.beatmap then
		local name = this.userdata.beatmap.name
		local si = this.userdata.beatmap.score_info or "-\n-\n-\n-"
		local ci = this.userdata.beatmap.combo_info or "-\n-\n-\n-"
		local din = this.userdata.beatmap.difficulty or "Unknown"
		
		love.graphics.print(si, 620, 152)
		love.graphics.print(ci, 800, 152)
		love.graphics.print(din, 600, 380)
		love.graphics.printf(this.userdata.beatmap.type, 600, 330, 316)
		
		--[[
		if this.userdata.cover_art then
			local w, h = this.userdata.cover_art:getDimensions()
			love.graphics.setColor(1, 1, 1)
			love.graphics.draw(this.userdata.cover_art, 440, 130, 0, 160 / w, 160 / h)
		end
		]]
	end
	
	return AquaShine.Node.draw(this)
end

function BeatmapInfoDL.setLiveIconImage(this, img)
	return this.child[3]:setImage(img)
end

return BeatmapInfoDL
