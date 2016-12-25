-- Main Menu

local DEPLS_VERSION = "20161224"
if not(_G.DEPLS_VERSION) then _G.DEPLS_VERSION = DEPLS_VERSION end

local MainMenu = {}

local LogicalScale = {
	ScreenX = 960,
	ScreenY = 640,
	OffX = 0,
	OffY = 0,
	ScaleOverall = 1
}

local selection_image = love.graphics.newImage("image/s_button_03.png")
local selection_image_se = love.graphics.newImage("image/s_button_03se.png")
local background = love.graphics.newImage("image/liveback_2.png")
local MTLMr3m = love.graphics.newFont("MTLmr3m.ttf", 30)
local mouse_data = {false, 0, 0}	-- click?, x click, y click

local menu_select = {
	-- Name, Func, Y pos, Mouse state (0 = none, 1 = highlight, 2 = selected)
	{"Play", function() end, nil, 0},
	{"Edit Units", function() end, nil, 0},
	{"Settings", function() end, nil, 0},
	{"Exit", love.event.quit, nil, 0}
}

local function calculate_touch_position(x, y)
	return
		(x - LogicalScale.OffX) / LogicalScale.ScaleOverall,
		(y - LogicalScale.OffY) / LogicalScale.ScaleOverall
end

function MainMenu.Start()
	-- Calculate display resolution scale
	LogicalScale.ScreenX, LogicalScale.ScreenY = love.graphics.getDimensions()
	LogicalScale.ScaleX = LogicalScale.ScreenX / 960
	LogicalScale.ScaleY = LogicalScale.ScreenY / 640
	LogicalScale.ScaleOverall = math.min(LogicalScale.ScaleX, LogicalScale.ScaleY)
	LogicalScale.OffX = (LogicalScale.ScreenX - LogicalScale.ScaleOverall * 960) / 2
	LogicalScale.OffY = (LogicalScale.ScreenY - LogicalScale.ScaleOverall * 640) / 2
	
	-- Pre-calculate Y position of buttons
	for i = 1, #menu_select do
		menu_select[i][3] = 120 + i * 80
	end
	
	love.graphics.setFont(MTLMr3m)
end

function MainMenu.Update(deltaT)
end

function MainMenu.Draw(deltaT)
	local draw = love.graphics.draw
	local drawtext = love.graphics.print
	local setColor = love.graphics.setColor
	
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
	
	setColor(64, 64, 255, 255)
	drawtext("DEPLS2 rel ".._G.DEPLS_VERSION, 3, 608)
	setColor(255, 255, 255, 255)
end

function love.update(deltaT)
	MainMenu.Update(deltaT * 1000)
end

function love.draw()
	local deltaT = love.timer.getDelta() * 1000
	
	love.graphics.push()
	love.graphics.translate(LogicalScale.OffX, LogicalScale.OffY)
	love.graphics.scale(LogicalScale.ScaleOverall, LogicalScale.ScaleOverall)
	MainMenu.Draw(deltaT)
	love.graphics.pop()
end

function love.mousepressed(x, y, button, touch_id)
	x, y = calculate_touch_position(x, y)
	
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
	x, y = calculate_touch_position(x, y)
	
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
	x, y = calculate_touch_position(x, y)
	
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

function love.resize(w, h)
	LogicalScale.ScreenX, LogicalScale.ScreenY = w, h
	LogicalScale.ScaleX = LogicalScale.ScreenX / 960
	LogicalScale.ScaleY = LogicalScale.ScreenY / 640
	LogicalScale.ScaleOverall = math.min(LogicalScale.ScaleX, LogicalScale.ScaleY)
	LogicalScale.OffX = (LogicalScale.ScreenX - LogicalScale.ScaleOverall * 960) / 2
	LogicalScale.OffY = (LogicalScale.ScreenY - LogicalScale.ScaleOverall * 640) / 2
end

return MainMenu
