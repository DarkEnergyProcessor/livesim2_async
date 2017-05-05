-- Unit Editor
-- Part of Live Simulator: 2

local AquaShine = AquaShine
local UnitEditor = {State = _G.SavedUnitEditorState}
local MouseState = {0, 0, false}	-- x, y, is click?
local IdolPosition = {	-- Idol position. 9 is leftmost
	{816, 96 }, {785, 249}, {698, 378},
	{569, 465}, {416, 496}, {262, 465},
	{133, 378}, {46 , 249}, {16 , 96 },
}

local Font

local dummy_image
local com_win_02
local com_button_01, com_button_01se

local function load_image(w)
	local x, r = pcall(love.graphics.newImage, "unit_icon/"..w)
	
	return x == true and r or dummy_image
end

local function distance(a, b)
	return math.sqrt(a ^ 2 + b ^ 2)
end

function UnitEditor.Start(arg)
	Font = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	love.graphics.setFont(Font)
	
	dummy_image = AquaShine.LoadImage("image/dummy.png")
	com_win_02 = AquaShine.LoadImage("image/com_win_02.png")
	com_button_01 = AquaShine.LoadImage("image/com_button_01.png")
	com_button_01se = AquaShine.LoadImage("image/com_button_01se.png")
	
	if not(UnitEditor.State) then
		local i = 9
		local units = AquaShine.LoadConfig("IDOL_IMAGE", "dummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy\tdummy")
		UnitEditor.State = {Changed = {}}
		
		for w in units:gmatch("[^\t]+") do
			UnitEditor.State[i] = load_image(w)
			
			i = i - 1
		end
		
		_G.SavedUnitEditorState = UnitEditor.State
	end
end

function UnitEditor.Update() end

function UnitEditor.Draw()
	love.graphics.clear(242, 59, 76)
	love.graphics.setColor(255, 255, 255)
	love.graphics.draw(com_win_02, -98, 0)
	
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
		
		if UnitEditor.State.Changed[i] then
			love.graphics.draw(UnitEditor.State.Changed[i], IdolPosition[i][1], IdolPosition[i][2])
		else
			love.graphics.draw(UnitEditor.State[i], IdolPosition[i][1], IdolPosition[i][2])
		end
			
		if distance(MouseState[1] - a[1] - 64, MouseState[2] - a[2] - 64) <= 64 then
			love.graphics.setColor(255, 255, 255, 96)
			love.graphics.circle("fill", a[1] + 64, a[2] + 64, 64)
			love.graphics.setColor(255, 255, 255)
		end
	end
	
	love.graphics.setColor(0, 0, 0)
	love.graphics.print("Change Units", 95, 13)
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
	
	if x >= 0 and x < 86 and y >= 0 and y < 58 then
		-- Discard changes
		_G.SavedUnitEditorState = nil
		AquaShine.LoadEntryPoint("main_menu.lua")
		
		return
	end
end

return UnitEditor
