-- Background image render
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local Node = AquaShine.Node
local love = love

local BackgroundImage = Node.Image:extend("Livesim2.BackgroundImage")

function BackgroundImage.init(this, id)
	Node.Image.init(this, assert(AquaShine.LoadImage("assets/image/background/liveback_"..id..".png")))
	
	for i = 1, 4 do
		this["image"..(i+1)] = AquaShine.LoadImage(string.format("assets/image/background/b_liveback_%03d_%02d.png", id, i))
	end
end

function BackgroundImage.draw(this)
	love.graphics.setColor(this.color)
	love.graphics.draw(this.image2, this.x - 88, this.y)
	love.graphics.draw(this.image3, this.x + 960, this.y)
	love.graphics.draw(this.image4, this.x, this.y - 43)
	love.graphics.draw(this.image5, this.x, this.y + 640)
	
	return Node.Image.draw(this)
end

return BackgroundImage
