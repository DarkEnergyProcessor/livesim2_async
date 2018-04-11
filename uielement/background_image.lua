-- Background image render
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local Node = AquaShine.Node
local BackgroundLoader = AquaShine.LoadModule("background_loader")

local BackgroundImage = Node.Image:extend("Livesim2.BackgroundImage")

function BackgroundImage.init(this, id)
	return Node.Image.init(this, BackgroundLoader.Load(id))
end

return BackgroundImage
