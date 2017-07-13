-- Beatmap selection screen, with NoteLoader2
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

--[[
TODO:
- Beatmap button, 75% scale, position in 60x80. Max 8 items, "y" flow (to bottom)
- Beatmap name, MTLmr3m.ttf 30px, position in 420x80, with outline
- Beatmap information, img com_win_40, position in 420x110, scale 85%
  - Beatmap cover (or "White"), position in 440x130, size 160x160 px
]]

local AquaShine = ...
local love = love
local NoteLoader = AquaShine.LoadModule("note_loader2")
local BeatmapSelect = {
	BeatmapTypeFont = AquaShine.LoadFont("MTLmr3m.ttf", 11),
	SongNameFont = AquaShine.LoadFont("MTLmr3m.ttf", 22),
	Page = 1,
	SwipeData = {nil, nil},	-- Touch handle (or 0 for mouse click), x1
	SwipeThreshold = 75,
}

BeatmapSelect.CompositionList = {}
BeatmapSelect.PageCompositionTable = {
	x = 64, y = 560, text = "Page 1",
	font = BeatmapSelect.SongNameFont,
	draw = function(this)
		love.graphics.setFont(this.font)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(this.text, 1, 1)
		love.graphics.print(this.text, -1, -1)
		love.graphics.setColor(255, 255, 255)
		love.graphics.print(this.text)
	end
}
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
		love.graphics.print("Beatmap Type:", 440, 340)
		love.graphics.print("Difficulty:", 440, 400)
		love.graphics.print("Audio Preview", 440, 440)
		
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
			
			love.graphics.printf(this.beatmap:GetBeatmapTypename(), 600, 340, 316)
			
			if din > 0 then
				local dir = this.beatmap:GetStarDifficultyInfo(true)
				
				if dir ~= din then
					love.graphics.print(string.format("%d* (Random %d*)", din, dir), 600, 400)
				else
					love.graphics.print(string.format("%d*", din), 600, 400)
				end
			else
				love.graphics.print("Unknown", 600, 400)
			end
			
			love.graphics.setFont(this.title)
			love.graphics.print(name, 419, 79)
			love.graphics.print(name, 421, 81)
			love.graphics.setColor(255, 255, 255)
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
BeatmapSelect.AutoplayTick = {
	x = 440, y = 502,
	w = 24, h = 24,
	tick = AquaShine.LoadImage("assets/image/ui/com_etc_293.png"),
	default = AquaShine.LoadImage("assets/image/ui/com_etc_292.png"),
	is_ticked = AquaShine.LoadConfig("AUTOPLAY") == 1,
	draw = function(this)
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(this.default)
		
		if this.is_ticked then
			love.graphics.draw(this.tick, -2, 0)
		end
		
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(BeatmapSelect.SongNameFont)
		love.graphics.print("Autoplay", 33, 2)
	end,
	click = function(this)
		this.is_ticked = not(this.is_ticked)
		AquaShine.SaveConfig("AUTOPLAY", this.is_ticked and "1" or "0")
	end
}
BeatmapSelect.RandomTick = {
	x = 440, y = 538,
	w = 24, h = 24,
	tick = AquaShine.LoadImage("assets/image/ui/com_etc_293.png"),
	default = AquaShine.LoadImage("assets/image/ui/com_etc_292.png"),
	is_ticked = false,
	draw = function(this)
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(this.default)
		
		if this.is_ticked then
			love.graphics.draw(this.tick, -2, 0)
		end
		
		love.graphics.setColor(0, 0, 0)
		love.graphics.setFont(BeatmapSelect.SongNameFont)
		love.graphics.print("Random", 33, 2)
	end,
	click = function(this)
		this.is_ticked = not(this.is_ticked)
	end
}
BeatmapSelect.MainUIComposition = AquaShine.Composition.Create {
	{
		-- Background
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
				love.graphics.setColor(255, 255, 255)
				love.graphics.draw(this.image_se)
			end,
			click = function()
				AquaShine.LoadEntryPoint("main_menu.lua")
			end
		}
	),
	BeatmapSelect.PageCompositionTable,
	{
		image = AquaShine.LoadImage("assets/image/ui/com_win_40.png"),
		x = 420, y = 110,
		draw = function(this)
			love.graphics.setColor(255, 255, 255)
			love.graphics.draw(this.image, 0, 0, 0, 0.85)
			love.graphics.rectangle("fill", 20, 20, 160, 160)
		end
	},
	BeatmapSelect.BeatmapInfoData,
	BeatmapSelect.AutoplayTick,
	BeatmapSelect.RandomTick,
	{
		x = 596, y = 430, w = 108, h = 43.5,
		buttons = {AquaShine.LoadImage(
			"assets/image/ui/button_play.png",
			"assets/image/ui/button_play_se.png",
			"assets/image/ui/button_play_di.png",
			"assets/image/ui/button_stop.png",
			"assets/image/ui/button_stop_se.png"
		)},
		draw = function(this)
			love.graphics.setColor(255, 255, 255)
			
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
			love.graphics.setColor(255, 255, 255)
			
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
				
				AquaShine.LoadEntryPoint("livesim.lua", {Beatmap = BeatmapSelect.BeatmapInfoData.beatmap, Random = BeatmapSelect.RandomTick.is_ticked})
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
					love.graphics.setColor(255, 255, 255)
					love.graphics.setFont(BeatmapSelect.SongNameFont)
					love.graphics.print(this.beatmap_info:GetName(), 16, 10)
					love.graphics.setColor(0, 0, 0)
					love.graphics.setFont(BeatmapSelect.BeatmapTypeFont)
					love.graphics.print(this.beatmap_info:GetBeatmapTypename(), 8, 40)
				end,
				draw = function(this)
					love.graphics.setColor(255, 255, 255)
					love.graphics.draw(this.select, 0, 0, 0, 0.75)
					this:draw_text()
				end,
				draw_se = function(this)
					love.graphics.setColor(255, 255, 255)
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

function BeatmapSelect.Update(deltaT)
end

function BeatmapSelect.Draw()
	BeatmapSelect.MainUIComposition:Draw()
	BeatmapSelect.CompositionList[BeatmapSelect.Page]:Draw()
end

function BeatmapSelect.Exit()
	if BeatmapSelect.BeatmapInfoData.beatmap_song then
		BeatmapSelect.BeatmapInfoData.beatmap_song:stop()
	end
end

function BeatmapSelect.MousePressed(x, y, k, tid)
	if not(BeatmapSelect.SwipeData[1]) then
		BeatmapSelect.SwipeData[1] = tid or 0
		BeatmapSelect.SwipeData[2] = x
	end
	
	BeatmapSelect.MainUIComposition:MousePressed(x, y)
	BeatmapSelect.CompositionList[BeatmapSelect.Page]:MousePressed(x, y)
end

function BeatmapSelect.MouseMoved(x, y)
	BeatmapSelect.MainUIComposition:MouseMoved(x, y)
	
	if BeatmapSelect.SwipeData[1] and math.abs(BeatmapSelect.SwipeData[2] - x) >= BeatmapSelect.SwipeThreshold then
		BeatmapSelect.CompositionList[BeatmapSelect.Page]:MouseMoved(-100, -100)	-- Guaranteed to abort it
	end
end

function BeatmapSelect.MouseReleased(x, y, k, tid)
	BeatmapSelect.MainUIComposition:MouseReleased(x, y)
	BeatmapSelect.CompositionList[BeatmapSelect.Page]:MouseReleased(x, y)
	
	if BeatmapSelect.SwipeData[1] then
		if math.abs(BeatmapSelect.SwipeData[2] - x) >= BeatmapSelect.SwipeThreshold then
			-- Switch page
			local is_left = BeatmapSelect.SwipeData[2] - x < 0
			
			BeatmapSelect.Page = ((BeatmapSelect.Page + (is_left and -2 or 0)) % #BeatmapSelect.CompositionList) + 1
			BeatmapSelect.SwipeData[2] = nil
			BeatmapSelect.PageCompositionTable.text = "Page "..BeatmapSelect.Page.."/"..#BeatmapSelect.CompositionList
		end
		
		BeatmapSelect.SwipeData[1] = nil
	end
end

function BeatmapSelect.KeyReleased(key)
	if key == "escape" then
		AquaShine.LoadEntryPoint("main_menu.lua")
	end
end

return BeatmapSelect, "Select Beatmap"
