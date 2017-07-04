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
local MainComposition = AquaShine.Composition.Create {
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
}

return AquaShine.Composition.Wrap(MainComposition)
