-- Beatmap information UI
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local BeatmapInfo = AquaShine.Node:extend("Livesim2.BeatmapInfo")
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local Checkbox = AquaShine.LoadModule("uielement.checkbox")

function BeatmapInfo.init(this, random_tick, NoteLoader)
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
			if this.userdata.beatmap.song then
				this.userdata.beatmap.song:stop()
			end
			
			-- 5th child is Random checkbox
			local params = {
				Beatmap = this.userdata.beatmap.data,
				Random = this.child[5]:isChecked(),
				NoStoryboard = not(this.child[6]:isChecked()),
				NoVideo = not(this.child[7]:isChecked())
			}
			
			if not(this.userdata.beatmap.data) then
				params.Beatmap = NoteLoader.NoteLoader(this.userdata.beatmap.filename)
			end
				
			AquaShine.LoadEntryPoint(":livesim_main", params)
		end
	)
		:setPosition(768, 529)
		:setDisabledImage(AquaShine.LoadImage("assets/image/ui/com_button_14di.png"))
		:disable()
	-- Audio Preview Play button
	this.child[3] = SimpleButton(
		AquaShine.LoadImage("assets/image/ui/button_play.png"),
		AquaShine.LoadImage("assets/image/ui/button_play_se.png"),
		function()
			if this.userdata.beatmap.song:isPlaying() then
				this.userdata.beatmap.song:stop()
				this.child[3].image = this.child[3].userdata.play
				this.child[3].image_se = this.child[3].userdata.play_se
			else
				this.userdata.beatmap.song:play()
				this.child[3].image = this.child[3].userdata.stop
				this.child[3].image_se = this.child[3].userdata.stop_se
			end
		end,
		0.75
	)
		:setPosition(596, 470)
		:setDisabledImage(AquaShine.LoadImage("assets/image/ui/button_play_di.png"))
		:disable()
	this.child[3].userdata.play = this.child[3].image
	this.child[3].userdata.play_se = this.child[3].image_se
	this.child[3].userdata.stop = AquaShine.LoadImage("assets/image/ui/button_stop.png")        -- Stop image
	this.child[3].userdata.stop_se = AquaShine.LoadImage("assets/image/ui/button_stop_se.png")  -- Stop image
	-- Autoplay checkbox
	this.child[4] = Checkbox("Autoplay", 440, 520, function(checked)
			AquaShine.SaveConfig("AUTOPLAY", checked and "1" or "0")
		end)
		:setColor(0, 0, 0)
		:setChecked(AquaShine.LoadConfig("AUTOPLAY", 0) == 1)
	-- Random checkbox
	this.child[5] = Checkbox("Random", 440, 556)
		:setColor(0, 0, 0)
		:setChecked(random_tick)
	-- Storyboard checkbox
	this.child[6] = Checkbox("Storyboard", 580, 520, function(checked)
			AquaShine.SaveConfig("STORYBOARD", checked and "1" or "0")
		end)
		:setColor(0, 0, 0)
		:setChecked(AquaShine.LoadConfig("STORYBOARD", AquaShine.IsSlowSystem() and 0 or 1) == 1)
	-- Video Background checkbox
	this.child[7] = Checkbox("Video Backgr.", 580, 556, function(checked)
			AquaShine.SaveConfig("VIDEOBG", checked and "1" or "0")
		end)
		:setColor(0, 0, 0)
		:setChecked(AquaShine.LoadConfig("VIDEOBG", AquaShine.IsSlowSystem() and 0 or 1) == 1)
end

function BeatmapInfo.setBeatmapData(this, beatmap)
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
	
	
	if this.userdata.beatmap and this.userdata.beatmap.song and this.userdata.beatmap.song:isPlaying() then
		this.child[3]:press()
	end
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
		mapdata.difficulty = beatmap:GetDifficultyString()
		
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

function BeatmapInfo.draw(this)
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
	love.graphics.print("Audio Preview", 440, 480)
	
	if this.userdata.beatmap then
		local name = this.userdata.beatmap.name
		local si = this.userdata.beatmap.score_info or "-\n-\n-\n-"
		local ci = this.userdata.beatmap.combo_info or "-\n-\n-\n-"
		local din = this.userdata.beatmap.difficulty or "Unknown"
		
		love.graphics.print(si, 620, 152)
		love.graphics.print(ci, 800, 152)
		love.graphics.print(din, 600, 380)
		love.graphics.printf(this.userdata.beatmap.type, 600, 330, 316)
		
		if this.userdata.beatmap.cover then
			local w, h = this.userdata.beatmap.cover.image:getDimensions()
			love.graphics.setColor(1, 1, 1)
			love.graphics.draw(this.userdata.beatmap.cover.image, 440, 130, 0, 160 / w, 160 / h)
			
			if this.userdata.beatmap.cover.arrangement then
				love.graphics.setColor(0, 0, 0)
				love.graphics.setFont(this.arrangementfont)
				love.graphics.printf(this.userdata.beatmap.cover.arrangement, 440, 296, 476)
			end
		end
	end
	
	return AquaShine.Node.draw(this)
end

return BeatmapInfo
