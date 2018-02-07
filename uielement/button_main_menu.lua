-- Main menu button UI element
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local Node = AquaShine.Node
local love = love

local MainMenuButton = Node.Image:extend("Livesim2.MainMenuButton")

function MainMenuButton.init(this, text, action)
	Node.Colorable.init(this)
	
	this.userdata.text = text
	this.userdata.targetimage = "image"
	this.userdata.font = AquaShine.LoadFont("MTLmr3m.ttf", 30)
	this.userdata.image = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
	this.userdata.image_se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
	Node.Util.InitializeInArea(this, this.userdata.image:getDimensions())
	
	this.events.MousePressed = Node.Util.InAreaFunction(this, function(x, y)
		this.userdata.targetimage = "image_se"
	end)
	this.events.MouseMoved = Node.Util.InAreaFunction(this, function(x, y)
		this.userdata.targetimage = "image"
	end, true)
	this.events.MouseReleased = Node.Util.InAreaFunction(this, function(x, y)
		if this.userdata.targetimage == "image_se" then
			action()
		end
		
		this.userdata.targetimage = "image"
	end)
end

function MainMenuButton.draw(this)
	love.graphics.setColor(this.color)
	love.graphics.draw(this.userdata[this.userdata.targetimage], this.x, this.y)
	love.graphics.setFont(this.userdata.font)
	love.graphics.print(this.userdata.text, this.x + 32, this.y + 16)
	
	return Node.Colorable.draw(this)
end

return MainMenuButton
