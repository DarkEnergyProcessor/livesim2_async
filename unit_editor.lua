-- Unit Editor
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = AquaShine
local UnitEditor = {State = _G.SavedUnitEditorState}
local MouseState = {0, 0, false}	-- x, y, is click?
local IdolPosition = {	-- Idol position. 9 is leftmost
	{816, 96 }, {785, 249}, {698, 378},
	{569, 465}, {416, 496}, {262, 465},
	{133, 378}, {46 , 249}, {16 , 96 },
}

local Font

local dummy_image = AquaShine.LoadImage("assets/image/dummy.png")
local com_win_02
local com_button_01, com_button_01se
local com_button_14, com_button_14se
local com_button_15, com_button_15se

local function load_image(w)
	local x, r = pcall(love.graphics.newImage, "unit_icon/"..w)
	
	return x == true and r or dummy_image
end

local function distance(a, b)
	return math.sqrt(a ^ 2 + b ^ 2)
end

local function applyChanges()
	local filelist = {}
	
	for i = 9, 1, -1 do
		filelist[#filelist + 1] = (UnitEditor.State.Changed[i] or UnitEditor.State[i]).Filename
		UnitEditor.State[i] = UnitEditor.State.Changed[i] or UnitEditor.State[i]
	end
	
	AquaShine.SaveConfig("IDOL_IMAGE", table.concat(filelist, "\t"))
end

function UnitEditor.Start(arg)
	Font = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	
	com_win_02 = AquaShine.LoadImage("assets/image/ui/com_win_02.png")
	com_button_01 = AquaShine.LoadImage("assets/image/ui/com_button_01.png")
	com_button_01se = AquaShine.LoadImage("assets/image/ui/com_button_01se.png")
	com_button_14 = AquaShine.LoadImage("assets/image/ui/com_button_14.png")
	com_button_14se = AquaShine.LoadImage("assets/image/ui/com_button_14se.png")
	com_button_15 = AquaShine.LoadImage("assets/image/ui/com_button_15.png")
	com_button_15se = AquaShine.LoadImage("assets/image/ui/com_button_15se.png")
	
	if not(UnitEditor.State) then
		local i = 9
		local units = AquaShine.LoadConfig("IDOL_IMAGE", "dummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy")
		UnitEditor.State = {Changed = {}}
		
		for w in units:gmatch("[^\t]+") do
			local temp = {}
			temp.Image = load_image(w)
			temp.Filename = w
			
			UnitEditor.State[i] = temp
			i = i - 1
		end
		
		_G.SavedUnitEditorState = UnitEditor.State
	end
	
	if type(arg[1]) == "table" then
		UnitEditor.State.Changed[UnitEditor.State.LastSelIdx] = arg[1]
	end
end

function UnitEditor.Update() end

function UnitEditor.Draw()
	love.graphics.setColor(242, 59, 76)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(com_win_02, -98, 0)
	love.graphics.setFont(Font)
	
	if MouseState[3] and
		MouseState[1] >= 0 and MouseState[1] < 86 and
		MouseState[2] >= 0 and MouseState[2] < 58
	then
		love.graphics.draw(com_button_01se)
	else
		love.graphics.draw(com_button_01)
	end
	
	for i = 1, 9 do
		local a = IdolPosition[i]
		
		love.graphics.draw((UnitEditor.State.Changed[i] or UnitEditor.State[i]).Image, IdolPosition[i][1], IdolPosition[i][2])
			
		if distance(MouseState[1] - a[1] - 64, MouseState[2] - a[2] - 64) <= 64 then
			love.graphics.setColor(255, 255, 255, 96)
			love.graphics.circle("fill", a[1] + 64, a[2] + 64, 64)
			love.graphics.setColor(255, 255, 255)
		end
	end
	
	if MouseState[3] then
		local x, y = MouseState[1], MouseState[2]
		
		if x >= 60 and x < 204 and y >= 556 and y < 614 then
			love.graphics.draw(com_button_15se, 60, 556)
		else
			love.graphics.draw(com_button_15, 60, 556)
		end
		
		if x >= 756 and x < 900 and y >= 556 and y < 614 then
			love.graphics.draw(com_button_14se, 756, 556)
		else
			love.graphics.draw(com_button_14, 756, 556)
		end
	else
		love.graphics.draw(com_button_15, 60, 556)
		love.graphics.draw(com_button_14, 756, 556)
	end
	
	love.graphics.setColor(0, 0, 0)
	love.graphics.print("Change Units", 95, 13)
	love.graphics.print("Click unit icon to change.", 337, 160)
	love.graphics.print("Please note that some beatmap", 320.5, 182)
	love.graphics.print("can override unit icon shown in here", 282, 204)
	love.graphics.print("Press OK to apply changes,", 337, 276)
	love.graphics.print("Cancel to discard any changes", 320.5, 298)
	love.graphics.print("Back to discard any changes and back to", 265.5, 320)
	love.graphics.print("Live Simulator: 2 main menu", 331.5, 342)
end

function UnitEditor.MousePressed(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = true
end

function UnitEditor.MouseMoved(x, y)
	MouseState[1], MouseState[2] = x, y
end

function UnitEditor.MouseReleased(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = false
	
	for i = 1, 9 do
		local a = IdolPosition[i]
		
		if distance(x - a[1] - 64, y - a[2] - 64) <= 64 then
			UnitEditor.State.LastSelIdx = i
			AquaShine.LoadEntryPoint("unit_selection.lua", {(UnitEditor.State.Changed[i] or UnitEditor.State[i]).Filename})
			
			return
		end
	end
	
	if x >= 0 and x < 86 and y >= 0 and y < 58 then
		-- Discard changes and back
		_G.SavedUnitEditorState = nil
		AquaShine.LoadEntryPoint("main_menu.lua")
		
		return
	elseif x >= 60 and x < 204 and y >= 556 and y < 614 then
		-- Cancel. Discard changes
		for i = 1, 9 do
			UnitEditor.State.Changed[i] = nil
		end
	elseif x >= 756 and x < 900 and y >= 556 and y < 614 then
		applyChanges()
	end
end

return UnitEditor, "Change Unit Icon"
