-- Main Menu
local AquaShine = AquaShine
local MainMenu = {}

local selection_image = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
local selection_image_se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
local background = AquaShine.LoadImage("assets/image/background/liveback_2.png")
local TitleIcon = AquaShine.LoadImage("assets/image/icon/icon_128x128.png")
local mouse_data = {false, 0, 0}	-- click?, x click, y click

local MTLMr3m = AquaShine.LoadFont("MTLmr3m.ttf", 30)
local TitleFont = AquaShine.LoadFont("MTLmr3m.ttf", 72)
local ReleaseFont = AquaShine.LoadFont("MTLmr3m.ttf", 16)
local MouseState = {X = 0, Y = 0, Pressed = false}

local menu_select = {
	-- Name, Func, Y pos, Mouse state (0 = none, 1 = highlight, 2 = selected)
	{"Play", function() AquaShine.LoadEntryPoint("select_beatmap.lua") end, nil},
	{"Change Units", function() AquaShine.LoadEntryPoint("unit_editor.lua") end, nil},
	{"Settings", function() AquaShine.LoadEntryPoint("setting_view.lua") end, nil},
	{"Exit", love.event.quit, nil}
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
local versionText = "Live Simulator: 2 version "..DEPLS_VERSION.." using "..(jit and jit.version or _VERSION).." for Lua interpreter\nPowered by AquaShine loader\nR/W Directory: "..love.filesystem.getSaveDirectory()
function MainMenu.Draw(deltaT)
	-- Draw background
	draw(background, 0, 0)
	setFont(MTLMr3m)
	
	for i = 1, #menu_select do
		local mobj = menu_select[i]
		
		if
			MouseState.Pressed and
			MouseState.X >= 16 and MouseState.Y >= mobj[3] and
			MouseState.X < 448 and MouseState.Y < mobj[3] + 80 then
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
	drawtext(versionText, 3, 591)
	setColor(255, 255, 255)
	drawtext(versionText, 2, 590)
	setColor(255, 255, 255)
end

function MainMenu.MousePressed(x, y, button, touch_id)
	MouseState.X, MouseState.Y, MouseState.Pressed = x, y, true
end

function MainMenu.MouseMoved(x, y)
	MouseState.X, MouseState.Y = x, y
end

function MainMenu.MouseReleased(x, y)
	MouseState.X, MouseState.Y, MouseState.Pressed = x, y, false
	
	if x >= 0 and y >= 589 and x < 332 and y < 624 then
		AquaShine.LoadEntryPoint("about_screen.lua")
		return
	end
	
	for i = 1, #menu_select do
		local mobj = menu_select[i]
		
		if x >= 16 and y >= mobj[3] and x < 448 and y < mobj[3] + 80 then
			mobj[2]()
			break
		end
	end
end

function MainMenu.KeyReleased(key, scancode)
	if key == "escape" then
		love.event.quit()
	end
end

return MainMenu, "Main Menu"
