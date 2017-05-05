-- Main Menu
local AquaShine = AquaShine
local MainMenu = {}

local selection_image = AquaShine.LoadImage("image/s_button_03.png")
local selection_image_se = AquaShine.LoadImage("image/s_button_03se.png")
local background = AquaShine.LoadImage("assets/image/background/liveback_2.png")
local TitleIcon = AquaShine.LoadImage("image/icon_128x128.png")
local mouse_data = {false, 0, 0}	-- click?, x click, y click

local MTLMr3m = AquaShine.LoadFont("MTLmr3m.ttf", 30)
local TitleFont = AquaShine.LoadFont("MTLmr3m.ttf", 72)
local ReleaseFont = AquaShine.LoadFont("MTLmr3m.ttf", 16)

local menu_select = {
	-- Name, Func, Y pos, Mouse state (0 = none, 1 = highlight, 2 = selected)
	{"Play", function() AquaShine.LoadEntryPoint("select_beatmap.lua") end, nil, 0},
	{"Change Units", function() AquaShine.LoadEntryPoint("unit_editor.lua") end, nil, 0},
	{"Settings", function() AquaShine.LoadEntryPoint("setting_view.lua") end, nil, 0},
	{"Exit", love.event.quit, nil, 0}
}

function MainMenu.Start()
	-- Pre-calculate Y position of buttons
	for i = 1, #menu_select do
		menu_select[i][3] = 120 + i * 80
	end
end

function MainMenu.Update(deltaT)
end

local draw = love.graphics.draw
local drawtext = love.graphics.print
local setColor = love.graphics.setColor
local setFont = love.graphics.setFont
local versionText = "livesim2 version "..DEPLS_VERSION.." using "..(jit and jit.version or _VERSION).." for Lua interpreter\nPowered by AquaShine loader"
function MainMenu.Draw(deltaT)
	-- Draw background
	draw(background, 0, 0)
	setFont(MTLMr3m)
	
	for i = 1, #menu_select do
		local mobj = menu_select[i]
		
		if mobj[4] == 2 then
			-- Draw selected
			draw(selection_image_se, 16, mobj[3])
		else
			draw(selection_image, 16, mobj[3])
		end
		
		drawtext(mobj[1], 48, mobj[3] + 16)
	end
	
	draw(TitleIcon, 140, 46)
	setFont(TitleFont)
	setColor(0, 0, 0, 127)
	drawtext("Live Simulator: 2", 282, 80)
	drawtext("Live Simulator: 2", 279, 77)
	setColor(255, 255, 255)
	drawtext("Live Simulator: 2", 280, 78)
	setFont(ReleaseFont)
	setColor(0, 0, 0)
	drawtext(versionText, 3, 607)
	setColor(255, 255, 255)
	drawtext(versionText, 2, 606)
	setColor(255, 255, 255)
end

function MainMenu.MousePressed(x, y, button, touch_id)
	for i = 1, #menu_select do
		local mobj = menu_select[i]
		
		if x >= 16 and x <= 448 and y >= mobj[3] and y <= mobj[3] + 80 then
			if mobj[4] == 1 then
				mobj[4] = 2
			end
			
			break
		end
	end
end

function MainMenu.MouseMoved(x, y)
	for i = 1, #menu_select do
		local mobj = menu_select[i]
		
		if x >= 16 and x <= 448 and y >= mobj[3] and y <= mobj[3] + 80 then
			if mobj[4] == 0 then
				mobj[4] = 1
			end
			
			break
		else
			mobj[4] = 0
		end
	end
end

function MainMenu.MouseReleased(x, y)
	for i = 1, #menu_select do
		local mobj = menu_select[i]
		
		if mobj[4] == 2 then
			mobj[2]()
			
			if x >= 16 and x <= 448 and y >= mobj[3] and y <= mobj[3] + 80 then
				mobj[4] = 1
			else
				mobj[4] = 0
			end
			
			break
		end
	end
end

return MainMenu
