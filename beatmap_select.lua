-- Beatmap selection screen, with NoteLoader2
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local NoteLoader = AquaShine.LoadModule("note_loader2")
local BeatmapSelect = assert(love.filesystem.load("beatmap_select_common.lua"))(AquaShine)

BeatmapSelect.BeatmapInfoData = {
	x = 0, y = 0,
	title = AquaShine.LoadFont("MTLmr3m.ttf", 30),
	arrangement_info = AquaShine.LoadFont("MTLmr3m.ttf", 16),
	draw = function(this)
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(BeatmapSelect.SongNameFont)
		love.graphics.print("Score", 620, 132)
		love.graphics.print("Combo", 800, 132)
		love.graphics.print("S\nA\nB\nC", 604, 152)
		love.graphics.print("Beatmap Type:", 440, 330)
		love.graphics.print("Difficulty:", 440, 380)
		love.graphics.print("Audio Preview", 440, 480)
		
		if this.beatmap then
			local name = this.beatmap:GetName()
			local si = this.beatmap:GetScoreInformation()
			local ci = this.beatmap:GetComboInformation()
			local din = this.beatmap:GetStarDifficultyInfo()
			
			if si then
				love.graphics.print(("%d\n%d\n%d\n%d"):format(
					si[4], si[3], si[2], si[1]
				), 620, 152)
			else
				love.graphics.print("-\n-\n-\n-", 620, 152)
			end
			
			if ci then
				love.graphics.print(("%d\n%d\n%d\n%d"):format(
					ci[4], ci[3], ci[2], ci[1]
				), 800, 152)
			else
				love.graphics.print("-\n-\n-\n-", 800, 152)
			end
			
			love.graphics.printf(this.beatmap:GetBeatmapTypename(), 600, 330, 316)
			
			if din > 0 then
				local dir = this.beatmap:GetStarDifficultyInfo(true)
				
				if dir ~= din then
					love.graphics.print(string.format("%d\226\152\134 (Random %d\226\152\134)", din, dir), 600, 380)
				else
					love.graphics.print(string.format("%d\226\152\134", din), 600, 380)
				end
			else
				love.graphics.print("Unknown", 600, 380)
			end
			
			love.graphics.setFont(this.title)
			love.graphics.print(name, 419, 79)
			love.graphics.print(name, 421, 81)
			love.graphics.setColor(1, 1, 1)
			love.graphics.print(name, 420, 80)
			
			if this.beatmap_cover then
				local w, h = this.beatmap_cover.image:getDimensions()
				love.graphics.draw(this.beatmap_cover.image, 440, 130, 0, 160 / w, 160 / h)
				
				if this.beatmap_cover.arrangement then
					love.graphics.setColor(0, 0, 0)
					love.graphics.setFont(this.arrangement_info)
					love.graphics.printf(this.beatmap_cover.arrangement, 440, 296, 476)
				end
			end
		end
	end
}

BeatmapSelect.MainUIComposition = AquaShine.Composition.Create {
	-- Background image
	{
		x = 0, y = 0,
		background = {AquaShine.LoadImage(
			"assets/image/background/liveback_1.png",
			"assets/image/background/b_liveback_001_01.png",
			"assets/image/background/b_liveback_001_02.png",
			"assets/image/background/b_liveback_001_03.png",
			"assets/image/background/b_liveback_001_04.png"
		)},
		draw = function(this)
			love.graphics.draw(this.background[1])
			love.graphics.draw(this.background[2], -88, 0)
			love.graphics.draw(this.background[3], 960, 0)
			love.graphics.draw(this.background[4], 0, -43)
			love.graphics.draw(this.background[5], 0, 640)
		end
	},
	-- Back button
	AquaShine.Composition.Template.Image(
		AquaShine.LoadImage("assets/image/ui/com_win_02.png"),
		-98, 0
	),
	AquaShine.Composition.Template.Text(
		AquaShine.LoadFont("MTLmr3m.ttf", 22),
		"Select Beatmap",
		95, 13, 0, 0, 0
	),
	AquaShine.Composition.Template.Image(
		AquaShine.LoadImage("assets/image/ui/com_button_01.png"),
		0, 0, true, {
			image_se = AquaShine.LoadImage("assets/image/ui/com_button_01se.png"),
			draw_se = function(this)
				love.graphics.setColor(1, 1, 1)
				love.graphics.draw(this.image_se)
			end,
			click = function()
				AquaShine.LoadEntryPoint(":main_menu")
			end
		}
	),
	BeatmapSelect.InsertBeatmapButton,
	BeatmapSelect.DownloadBeatmapButton,
	BeatmapSelect.OpenBeatmapButton,
	-- Page numbering
	BeatmapSelect.PageCompositionTable,
	{
		image = AquaShine.LoadImage("assets/image/ui/com_win_40.png"),
		x = 420, y = 110,
		draw = function(this)
			love.graphics.setColor(1, 1, 1)
			love.graphics.draw(this.image, 0, 0, 0, 0.85)
			love.graphics.rectangle("fill", 20, 20, 160, 160)
		end
	},
	-- Beatmap information
	BeatmapSelect.BeatmapInfoData,
	-- Autoplay tick
	BeatmapSelect.AutoplayTick,
	-- Random tick
	BeatmapSelect.RandomTick,
	-- Audio preview button
	{
		x = 596, y = 470, w = 108, h = 43.5,
		buttons = {AquaShine.LoadImage(
			"assets/image/ui/button_play.png",
			"assets/image/ui/button_play_se.png",
			"assets/image/ui/button_play_di.png",
			"assets/image/ui/button_stop.png",
			"assets/image/ui/button_stop_se.png"
		)},
		draw = function(this)
			love.graphics.setColor(1, 1, 1)
			
			if not(BeatmapSelect.BeatmapInfoData.beatmap_song) then
				love.graphics.draw(this.buttons[3], 0, 0, 0, 0.75)
				return
			end
			
			love.graphics.draw(
				BeatmapSelect.BeatmapInfoData.beatmap_song:isPlaying() and this.buttons[4] or this.buttons[1],
				0, 0, 0, 0.75
			)
		end,
		draw_se = function(this)
			love.graphics.setColor(1, 1, 1)
			
			if not(BeatmapSelect.BeatmapInfoData.beatmap_song) then
				love.graphics.draw(this.buttons[3], 0, 0, 0, 0.75)
				return
			end
			
			love.graphics.draw(
				BeatmapSelect.BeatmapInfoData.beatmap_song:isPlaying() and this.buttons[5] or this.buttons[2],
				0, 0, 0, 0.75
			)
		end,
		click = function(this)
			if BeatmapSelect.BeatmapInfoData.beatmap_song then
				if BeatmapSelect.BeatmapInfoData.beatmap_song:isPlaying() then
					BeatmapSelect.BeatmapInfoData.beatmap_song:stop()
				else
					BeatmapSelect.BeatmapInfoData.beatmap_song:play()
				end
			end
		end
	},
	-- Start beatmap button
	{
		x = 768, y = 529, w = 144, h = 58,
		buttons = {AquaShine.LoadImage(
			"assets/image/ui/com_button_14.png",
			"assets/image/ui/com_button_14di.png",
			"assets/image/ui/com_button_14se.png"
		)},
		draw = function(this)
			love.graphics.draw(BeatmapSelect.BeatmapInfoData.beatmap and this.buttons[1] or this.buttons[2])
		end,
		draw_se = function(this)
			love.graphics.draw(BeatmapSelect.BeatmapInfoData.beatmap and this.buttons[3] or this.buttons[2])
		end,
		click = function(this)
			if BeatmapSelect.BeatmapInfoData.beatmap then
				if BeatmapSelect.BeatmapInfoData.beatmap_song then
					BeatmapSelect.BeatmapInfoData.beatmap_song:stop()
				end
				
				AquaShine.LoadEntryPoint(":livesim_main", {Beatmap = BeatmapSelect.BeatmapInfoData.beatmap, Random = BeatmapSelect.RandomTick.is_ticked})
			end
		end
	}
}

function BeatmapSelect.Start(arg)
	local beatmap_list = NoteLoader.Enumerate()
	
	-- Sort by name
	table.sort(beatmap_list, function(a, b)
		return a:GetName() < b:GetName()
	end)
	
	for i = 1, math.ceil(#beatmap_list / 8) do
		local list = {}	-- Composition
		
		for j = 1, 8 do
			local idx = (i - 1) * 8 + j
			local composition
			
			if not(beatmap_list[idx]) then break end
			
			composition = {
				x = 60, y = (j - 1) * 60 + 80, w = 324, h = 60,
				beatmap_info = beatmap_list[idx],
				select = AquaShine.LoadImage("assets/image/ui/s_button_03.png"),
				select_se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png"),
				
				draw_text = function(this)
					love.graphics.setColor(1, 1, 1)
					love.graphics.setFont(BeatmapSelect.SongNameFont)
					love.graphics.print(this.beatmap_info:GetName(), 16, 10)
					love.graphics.setColor(0, 0, 0)
					love.graphics.setFont(BeatmapSelect.BeatmapTypeFont)
					love.graphics.print(this.beatmap_info:GetBeatmapTypename(), 8, 40)
				end,
				draw = function(this)
					love.graphics.setColor(1, 1, 1)
					love.graphics.draw(this.select, 0, 0, 0, 0.75)
					this:draw_text()
				end,
				draw_se = function(this)
					love.graphics.setColor(1, 1, 1)
					love.graphics.draw(this.select_se, 0, 0, 0, 0.75)
					this:draw_text()
				end,
				click = function(this)
					if BeatmapSelect.BeatmapInfoData.beatmap then
						BeatmapSelect.BeatmapInfoData.beatmap:ReleaseBeatmapAudio()
					end
					
					local audio = this.beatmap_info:GetBeatmapAudio()
					BeatmapSelect.BeatmapInfoData.beatmap = this.beatmap_info
					BeatmapSelect.BeatmapInfoData.beatmap_cover = this.beatmap_info:GetCoverArt()
					
					if BeatmapSelect.BeatmapInfoData.beatmap_song then
						BeatmapSelect.BeatmapInfoData.beatmap_song:stop()
						BeatmapSelect.BeatmapInfoData.beatmap_song = nil
					end
					
					
					if audio then
						BeatmapSelect.BeatmapInfoData.beatmap_song = love.audio.newSource(audio)
					end
				end
			}
			list[#list + 1] = composition
		end
		
		BeatmapSelect.CompositionList[#BeatmapSelect.CompositionList + 1] = AquaShine.Composition.Create(list)
	end
	
	BeatmapSelect.PageCompositionTable.text = "Page "..BeatmapSelect.Page.."/"..#BeatmapSelect.CompositionList
end

function BeatmapSelect.Exit()
	if BeatmapSelect.BeatmapInfoData.beatmap_song then
		BeatmapSelect.BeatmapInfoData.beatmap_song:stop()
	end
end

return BeatmapSelect, "Select Beatmap"
