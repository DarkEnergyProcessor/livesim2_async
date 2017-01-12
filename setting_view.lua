-- DEPLS settings

local love = love
local Settings = {
	Config = {	-- Default configuration
		AUTOPLAY = 0,
		BACKGROUND_IMAGE = 11,
		IDOL_KEYS = "a\ts\td\tf\tspace\tj\tk\tl\t;",
		LIVESIM_DELAY = 1000,
		LLP_SIFT_DEFATTR = 1,
		NOTE_SPEED = 800,
		SCORE_ADD_NOTE = 1024,
		STAMINA_DISPLAY = 32
	},
	CurrentConfig = {},	-- Current configuration
	Background = love.graphics.newImage("image/liveback_5.png"),
	BackImage = love.graphics.newImage("image/com_win_02.png"),
	BackButton = love.graphics.newImage("image/com_button_01.png"),
	BackButtonSe = love.graphics.newImage("image/com_button_01se.png"),
	
	FontConfig = love.graphics.newFont("MTLmr3m.ttf", 30),
	FontDesc = love.graphics.newFont("MTLmr3m.ttf", 22),
	DescImage = love.graphics.newImage("image/com_win_42.png"),
}

local MouseState = {0, 0, false}	-- x, y, is click?
local DescContentX = 464 + 20
local DescContentY = 236 + 20

local ConfigList = {
	{
		-- The configuration name
		Name = "Autoplay",
		-- Function to be called if it's shown
		Show = function(this, deltaT)
			
		end,
		-- Function to be called if "Default Setting" is clicked
		SetDefault = function(this)
		end,
		-- Function to be called if "Apply Setting" is clicked
		Set = function(this)
		end,
		-- Function to be called on left click
		Click = function(this, x, y)
		end,
		-- Function to be called on left click release
		ClickRelease = function(this, x, y)
		end,
		
		-- Your additional properties below
		OnButton = love.graphics.newImage("image/set_button_14.png"),
		OnButtonSe = love.graphics.newImage("image/set_button_14se.png"),
		OffButton = love.graphics.newImage("image/set_button_15.png"),
		OffButtonSe = love.graphics.newImage("image/set_button_15se.png"),
	}
}

-- Usual configuration settings
function Settings.Start()
	for n, v in pairs(Settings.Config) do
		Settings.CurrentConfig[n] = LoadConfig(n, v)
	end
	
	
end

function Settings.Update(deltaT)
end

function Settings.Draw(deltaT)
	-- Draw background
	love.graphics.draw(Settings.Background)
	
	-- Draw back button and image
	love.graphics.draw(Settings.BackImage, -98, 0)
	
	if
		MouseState[3] and
		MouseState[1] >= 0 and MouseState[1] <= 86 and
		MouseState[2] >= 0 and MouseState[2] <= 58
	then
		-- Draw se
		love.graphics.draw(Settings.BackButtonSe)
	else
		-- Draw normal
		love.graphics.draw(Settings.BackButton)
	end
	
	-- Draw label
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("Settings", 95, 13)
	love.graphics.setColor(255, 255, 255, 255)
end

function love.mousepressed(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = CalculateTouchPosition(x, y)
	MouseState[3] = true
end

function love.mousemoved(x, y)
	MouseState[1], MouseState[2] = CalculateTouchPosition(x, y)
end

function love.mousereleased(x, y, button)
	if button ~= 1 then return end
	
	x, y = CalculateTouchPosition(x, y)
	
	MouseState[1], MouseState[2] = CalculateTouchPosition(x, y)
	MouseState[3] = false
	
	if x >= 0 and x <= 86 and y >= 0 and y <= 58 then
		-- Exit settings
		LoadEntryPoint("main_menu.lua")
	end
end

return Settings
