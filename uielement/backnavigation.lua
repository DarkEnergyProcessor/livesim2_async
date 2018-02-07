-- Back button navigation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BackNavigation = SimpleButton:extend("Livesim2.BackNavigation")

function BackNavigation.init(this, name, back_entry_point, arg)
	SimpleButton.init(this,
		AquaShine.LoadImage("assets/image/ui/com_button_01.png"),
		AquaShine.LoadImage("assets/image/ui/com_button_01se.png"),
		function()
			AquaShine.LoadEntryPoint(back_entry_point, arg)
		end
	)
	this.userdata.bgbackbtn = AquaShine.LoadImage("assets/image/ui/com_win_02.png")
	this.userdata.textfont = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	this.userdata.name = name
end

function BackNavigation.draw(this)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(this.userdata.bgbackbtn, this.x - 98, this.y)
	love.graphics.setColor(0, 0, 0)
	love.graphics.setFont(this.userdata.textfont)
	love.graphics.print(this.userdata.name, this.x + 95, this.y + 13)
	
	return SimpleButton.draw(this)
end

return BackNavigation
