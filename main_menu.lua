-- Main Menu
local MainMenu = {}

local selection_image = love.graphics.newImage("image/s_button_03.png")
local selection_image_se = love.graphics.newImage("image/s_button_03se.png")
local background = love.graphics.newImage("image/liveback_2.png")
local MTLMr3m = FontManager.GetFont("MTLmr3m.ttf", 30)
local TitleFont = FontManager.GetFont("MTLmr3m.ttf", 72)
local TitleIcon = love.graphics.newImage("image/icon_128x128.png")
local mouse_data = {false, 0, 0}	-- click?, x click, y click

local menu_select = {
	-- Name, Func, Y pos, Mouse state (0 = none, 1 = highlight, 2 = selected)
	{"Play", function() LoadEntryPoint("select_beatmap.lua") end, nil, 0},
	{"Edit Units", function() end, nil, 0},
	{"Settings", function() LoadEntryPoint("setting_view.lua") end, nil, 0},
	{"Exit", love.event.quit, nil, 0}
}

function MainMenu.Start()
	-- Pre-calculate Y position of buttons
	for i = 1, #menu_select do
		menu_select[i][3] = 120 + i * 80
	end
	
	love.graphics.setFont(MTLMr3m)
end

function MainMenu.Update(deltaT)
end

local draw = love.graphics.draw
local drawtext = love.graphics.print
local setColor = love.graphics.setColor
local setFont = love.graphics.setFont
function MainMenu.Draw(deltaT)
	
	-- Draw background
	draw(background, 0, 0)
	
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
	setColor(255, 255, 255, 255)
	drawtext("Live Simulator: 2", 280, 78)
	setColor(64, 64, 255, 255)
	setFont(MTLMr3m)
	drawtext("DEPLS2 rel ".._G.DEPLS_VERSION, 3, 608)
	setColor(255, 255, 255, 255)
end
jit.off(MainMenu.Draw)

function love.mousepressed(x, y, button, touch_id)
	x, y = CalculateTouchPosition(x, y)
	
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

function love.mousemoved(x, y)
	x, y = CalculateTouchPosition(x, y)
	
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

function love.mousereleased(x, y)
	x, y = CalculateTouchPosition(x, y)
	
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
