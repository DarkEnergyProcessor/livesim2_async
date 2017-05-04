-- Unit selection page
-- Part of Live Simulator: 2

local love = love
local AquaShine = AquaShine
local UnitSelect = {CurrentPage = 0}
local MouseState = {0, 0, false}	-- x, y, is click?

local Font
local com_etc_117
local com_win_02
local com_button_01, com_button_01se
local com_button_12, com_button_12se
local com_button_13, com_button_13se

function UnitSelect.Start(arg)
	UnitSelect.Options = arg
	UnitSelect.UnitList = {}
	
	for i, v in ipairs(love.filesystem.getDirectoryItems("unit_icon")) do
		local name = "unit_icon/"..v
		if v:sub(-4) == ".png" and love.filesystem.isFile(name) then
			local temp = {}
			
			-- Load image. Do not use AquaShine.LoadImage for images in R/W dir
			-- Instead, use traditional love.graphics.newImage
			temp.Image = love.graphics.newImage(name)
			temp.Filename = v
			
			if temp.Image:getWidth() == 128 and temp.Image:getHeight() == 128 then
				UnitSelect.UnitList[#UnitSelect.UnitList + 1] = temp
			end
		end
	end
	
	com_etc_117 = AquaShine.LoadImage("assets/image/ui/com_etc_117.png")
	com_win_02 = AquaShine.LoadImage("image/com_win_02.png")
	com_button_01 = AquaShine.LoadImage("image/com_button_01.png")
	com_button_01se = AquaShine.LoadImage("image/com_button_01se.png")
	com_button_12 = AquaShine.LoadImage("assets/image/ui/com_button_12.png")
	com_button_12se = AquaShine.LoadImage("assets/image/ui/com_button_12se.png")
	com_button_13 = AquaShine.LoadImage("assets/image/ui/com_button_13.png")
	com_button_13se = AquaShine.LoadImage("assets/image/ui/com_button_13se.png")
	
	Font = AquaShine.LoadFont("MTLmr3m.ttf", 22)
end

function UnitSelect.Update(deltaT)
end

local CurrentHoverCardIdx
function UnitSelect.Draw()
	AquaShine.SetScissor(0, 0, 960, 640)
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(com_win_02, -98, 0)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print("Unit Select", 95, 13)
	love.graphics.setColor(255, 255, 255)
	AquaShine.ClearScissor()
	
	if MouseState[3] then
		if
			MouseState[1] >= 0 and MouseState[1] < 86 and
			MouseState[2] >= 0 and MouseState[2] < 58
		then
			love.graphics.draw(com_button_01se)
		else
			love.graphics.draw(com_button_01)
		end
		
		if
			MouseState[1] >= 0 and MouseState[1] < 32 and
			MouseState[2] >= 298 and MouseState[2] < 354
		then
			love.graphics.draw(com_button_12se, -8, 298)
		else
			love.graphics.draw(com_button_12, -8, 298)
		end
		
		if
			MouseState[1] >= 928 and MouseState[1] < 960 and
			MouseState[2] >= 298 and MouseState[2] < 354
		then
			love.graphics.draw(com_button_13se, 920, 298)
		else
			love.graphics.draw(com_button_13, 920, 298)
		end
	else
		love.graphics.draw(com_button_01)
		love.graphics.draw(com_button_12, -8, 298)
		love.graphics.draw(com_button_13, 920, 298)
	end
	
	love.graphics.rectangle("fill", 32, 70, 896, 512)
	
	for i = 1 + UnitSelect.CurrentPage * 28, 28 do
		if UnitSelect.UnitList[i] then
			-- Order, goes down
			local j = i - 1
			
			love.graphics.draw(UnitSelect.UnitList[i].Image, math.floor(j * 0.25) * 128 + 32, (j % 4) * 128 + 70)
		end
	end
	
	if CurrentHoverCardIdx and UnitSelect.UnitList[CurrentHoverCardIdx + 1] then
		local a = UnitSelect.UnitList[CurrentHoverCardIdx + 1]
		local txtlen = Font:getWidth(a.Filename)
		
		love.graphics.setFont(Font)
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("line", math.floor(CurrentHoverCardIdx * 0.25) * 128 + 32, (CurrentHoverCardIdx % 4) * 128 + 70, 128, 128)
		love.graphics.setColor(255, 56, 122)
		love.graphics.rectangle("fill", MouseState[1] + 8, MouseState[2] + 8, txtlen + 10, 26)
		love.graphics.setColor(0, 0, 0)
		love.graphics.print(a.Filename, MouseState[1] + 14, MouseState[2] + 13)
		love.graphics.setColor(255, 255, 255)
		love.graphics.print(a.Filename, MouseState[1] + 13, MouseState[2] + 12)
		love.graphics.setColor(0, 0, 0)
	end
end

function UnitSelect.MousePressed(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = true
end

function UnitSelect.MouseMoved(x, y)
	MouseState[1], MouseState[2] = x, y
	
	if x >= 32 and y >= 70 and
	   y < 896 and y < 582
	then
		CurrentHoverCardIdx = (math.floor((x - 32) / 128) * 4 + math.floor((y - 70) / 128) % 4)
		
		if CurrentHoverCardIdx >= (UnitSelect.CurrentPage + 1) * 28 then
			CurrentHoverCardIdx = nil
		end
	else
		CurrentHoverCardIdx = nil
	end
end

function UnitSelect.MouseReleased(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = false
	
	if x >= 0 and x <= 86 and y >= 0 and y <= 58 then
		-- Exit unit editor
		-- TODO: Save changes
		AquaShine.LoadEntryPoint("main_menu.lua")
	end
end

return UnitSelect
