-- Beatmap information UI (download)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local BeatmapInfoDL = AquaShine.Node:extend("Livesim2.BeatmapInfoDL")
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local CoverArtLoading = AquaShine.LoadModule("external.cover_art_loading")

function BeatmapInfoDL.init(this, track_data, NoteLoader)
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
	this.trackdata = track_data
end

function BeatmapInfoDL.setBeatmapIndex(this, index)
	-- index is difficulty name
	this.beatmapidx = index
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
		local name = this.trackdata.name
		local si = this.score_info or "-\n-\n-\n-"
		local ci = this.combo_info or "-\n-\n-\n-"
		local din = this.difficulty or "Unknown"
		
		love.graphics.print(si, 620, 152)
		love.graphics.print(ci, 800, 152)
		love.graphics.print(din, 600, 380)
		--love.graphics.printf(this.userdata.beatmap.type, 600, 330, 316)
		
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
