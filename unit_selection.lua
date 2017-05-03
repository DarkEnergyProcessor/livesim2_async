-- Unit selection page
-- Part of Live Simulator: 2

local AquaShine = AquaShine
local UnitSelect = {}

local com_etc_117

function UnitSelect.Start(arg)
	UnitSelect.Options = arg
	UnitSelect.UnitList = {}
	
	for i, v in ipairs(love.filesystem.getDirectoryItems("unit_icon")) do
		if v:sub(-4) == ".png" and love.filesystem.isFile(v) then
			-- Load image. Do not use AquaShine.LoadImage for images in R/W dir
			-- Instead, use traditional love.graphics.newImage
			
			local temp = {}
			temp.Image = love.graphics.newImage(v)
			temp.Filename = v
		end
	end
	
	com_etc_117 = AquaShine.LoadImage("assets/image/ui/com_etc_117.png")
end

function UnitSelect.Update(deltaT)
end

function UnitSelect.Draw()
end

return UnitSelect
