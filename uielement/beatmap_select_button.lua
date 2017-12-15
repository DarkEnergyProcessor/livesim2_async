-- Beatmap selection button
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BeatmapSelButton = SimpleButton:extend("Livesim2.BeatmapSelButton")

function BeatmapSelButton.init(this, beatmap_data, beatmap_info_node)
	SimpleButton.init(this,
		AquaShine.LoadImage("assets/image/ui/s_button_03.png"),
		AquaShine.LoadImage("assets/image/ui/s_button_03se.png"),
		function()
			beatmap_info_node:setBeatmapData(beatmap_data)
		end,
		0.75
	)
	
	this.namefont = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	this.typefont = AquaShine.LoadFont("MTLmr3m.ttf", 11)
	
	if beatmap_data.__name and beatmap_data.__name:find("NoteLoader.", 1, true) == 1 then
		this.userdata.name = beatmap_data:GetName()
		this.userdata.type = beatmap_data:GetBeatmapTypename()
	else
		this.userdata.name = beatmap_data.name
		this.userdata.type = beatmap_data.type
	end
end

function BeatmapSelButton.draw(this)
	love.graphics.draw(this[this.userdata.targetimage] or this.image, this.x, this.y, 0, this.scale)
	love.graphics.setColor(1, 1, 1)
	love.graphics.setFont(this.namefont)
	love.graphics.print(this.userdata.name, this.x + 16, this.y + 10)
	love.graphics.setColor(0, 0, 0)
	love.graphics.setFont(this.typefont)
	love.graphics.print(this.userdata.type, this.x + 8, this.y + 40)
	
	return AquaShine.Node.draw(this)
end

return BeatmapSelButton
