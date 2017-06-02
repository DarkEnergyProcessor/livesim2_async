-- Unit selection page
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = love
local AquaShine = AquaShine
local UnitSelect = {CurrentPage = 0}
local MouseState = {0, 0, false}	-- x, y, is click?

local Font
local background_5
local com_etc_117
local com_win_02
local com_button_14, com_button_14di, com_button_14se
local com_button_01, com_button_01se
local com_button_12, com_button_12se
local com_button_13, com_button_13se

local NewUnitsInstalled = false
local CurrentHoverCardIdx
local CurrentSelectedCardIdx = 0

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
				
				if temp.Filename == arg[1] then
					CurrentSelectedCardIdx = #UnitSelect.UnitList
					UnitSelect.CurrentPage = math.floor(CurrentSelectedCardIdx / 28)
				end
			end
			
		end
	end
	
	background_5 = AquaShine.LoadImage("assets/image/background/liveback_5.png")
	com_etc_117 = AquaShine.LoadImage("assets/image/ui/com_etc_117.png")
	com_win_02 = AquaShine.LoadImage("assets/image/ui/com_win_02.png")
	com_button_14 = AquaShine.LoadImage("assets/image/ui/com_button_14.png")
	com_button_14di = AquaShine.LoadImage("assets/image/ui/com_button_14di.png")
	com_button_14se = AquaShine.LoadImage("assets/image/ui/com_button_14se.png")
	com_button_01 = AquaShine.LoadImage("assets/image/ui/com_button_01.png")
	com_button_01se = AquaShine.LoadImage("assets/image/ui/com_button_01se.png")
	com_button_12 = AquaShine.LoadImage("assets/image/ui/com_button_12.png")
	com_button_12se = AquaShine.LoadImage("assets/image/ui/com_button_12se.png")
	com_button_13 = AquaShine.LoadImage("assets/image/ui/com_button_13.png")
	com_button_13se = AquaShine.LoadImage("assets/image/ui/com_button_13se.png")
	
	Font = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	love.graphics.setFont(Font)
end

function UnitSelect.Update(deltaT)
	if NewUnitsInstalled then
		local SelIdx
		
		if CurrentSelectedCardIdx > 0 then
			SelIdx = assert(UnitSelect.UnitList[CurrentSelectedCardIdx]).Filename
		end
		
		AquaShine.LoadEntryPoint("unit_selection.lua", {SelIdx})
	end
end

function UnitSelect.Draw()
	AquaShine.SetScissor(0, 0, 960, 640)
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(background_5)
	love.graphics.draw(com_win_02, -98, 0)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print("Unit Select", 95, 13)
	love.graphics.print(string.format("Page %d", UnitSelect.CurrentPage + 1), 34, 576)
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
			MouseState[2] >= 288 and MouseState[2] < 344
		then
			love.graphics.draw(com_button_12se, -8, 288)
		else
			love.graphics.draw(com_button_12, -8, 288)
		end
		
		if
			MouseState[1] >= 928 and MouseState[1] < 960 and
			MouseState[2] >= 288 and MouseState[2] < 344
		then
			love.graphics.draw(com_button_13se, 920, 288)
		else
			love.graphics.draw(com_button_13, 920, 288)
		end
		
		if CurrentSelectedCardIdx > 0 then
			if
				MouseState[1] >= 772 and MouseState[1] < 916 and
				MouseState[2] >= 576 and MouseState[2] < 634 and CurrentSelectedCardIdx > 0
			then
				love.graphics.draw(com_button_14se, 772, 576)
			else
				love.graphics.draw(com_button_14, 772, 576)
			end
		else
			love.graphics.draw(com_button_14di, 772, 576)
		end
	else
		love.graphics.draw(com_button_01)
		love.graphics.draw(com_button_12, -8, 288)
		love.graphics.draw(com_button_13, 920, 288)
		
		if CurrentSelectedCardIdx > 0 then
			love.graphics.draw(com_button_14, 772, 576)
		else
			love.graphics.draw(com_button_14di, 772, 576)
		end
	end
	
	love.graphics.rectangle("fill", 32, 60, 896, 512)
	
	for i = 1 + UnitSelect.CurrentPage * 28, (UnitSelect.CurrentPage + 1) * 28 do
		if UnitSelect.UnitList[i] then
			-- Order, goes down
			local j = (i - UnitSelect.CurrentPage * 28 - 1)
			local x =  math.floor(j * 0.25) * 128 + 32
			local y = (j % 4) * 128 + 60
			
			love.graphics.draw(UnitSelect.UnitList[i].Image, x, y)
			
			if CurrentSelectedCardIdx == i then
				love.graphics.draw(com_etc_117, x, y)
			end
		end
	end
	
	if CurrentHoverCardIdx and UnitSelect.UnitList[CurrentHoverCardIdx + 1] then
		local a = UnitSelect.UnitList[CurrentHoverCardIdx + 1]
		local j = (CurrentHoverCardIdx - UnitSelect.CurrentPage * 28)
		local txtlen = Font:getWidth(a.Filename)
		
		love.graphics.setColor(0, 0, 0)
		love.graphics.rectangle("line", math.floor(j * 0.25) * 128 + 32, (j % 4) * 128 + 60, 128, 128)
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
	
	if x >= 32 and y >= 60 and
	   x < 928 and y < 572
	then
		CurrentHoverCardIdx = (math.floor((x - 32) / 128) * 4 + math.floor((y - 60) / 128) % 4) + UnitSelect.CurrentPage * 28
		
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
	
	if x >= 0 and x < 86 and y >= 0 and y < 58 then
		-- Exit unit editor
		AquaShine.LoadEntryPoint("unit_editor.lua")
		return
	elseif x >= 0 and x < 32 and y >= 288 and y < 344 then
		-- Previous
		UnitSelect.CurrentPage = math.max(UnitSelect.CurrentPage - 1, 0)
	elseif x >= 928 and x < 960 and y >= 288 and y < 344 then
		-- Next
		UnitSelect.CurrentPage = math.min(math.floor(math.max(#UnitSelect.UnitList - 1, 0) / 28), UnitSelect.CurrentPage + 1)
	elseif x >= 32 and y >= 60 and x < 928 and y < 572 then
		-- Select
		CurrentSelectedCardIdx = (math.floor((x - 32) / 128) * 4 + math.floor((y - 60) / 128) % 4) + UnitSelect.CurrentPage * 28 + 1
		
		if not(UnitSelect.UnitList[CurrentSelectedCardIdx]) then
			CurrentSelectedCardIdx = 0
		end
	elseif  x >= 772 and x < 916 and y >= 576 and y < 634 and CurrentSelectedCardIdx > 0 then
		AquaShine.LoadEntryPoint("unit_editor.lua", {UnitSelect.UnitList[CurrentSelectedCardIdx]})
	else
		CurrentSelectedCardIdx = 0
	end
end

function UnitSelect.FileDropped(file)
	local filename = file:getFilename()
	
	if filename:sub(-4) == ".png" then
		local file_dest = "unit_icon/"..AquaShine.Basename(filename)
			
		if not(love.filesystem.isFile(file_dest)) then
			local img = love.image.newImageData(file)
			
			if img:getWidth() == 128 and img:getHeight() == 128 then
				assert(file:open("r"))
				
				love.filesystem.write(file_dest, file:read())
				file:close()
				
				NewUnitsInstalled = true
			end
		end
	end
end

return UnitSelect, "Unit Icon Selection"
