-- DEPLS settings
-- Copyright © 2038 Dark Energy Processor
-- TODO: complete it

local love = love
local AquaShine = AquaShine
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
	BackImage = AquaShine.LoadImage("image/com_win_02.png"),
	BackButton = AquaShine.LoadImage("image/com_button_01.png"),
	BackButtonSe = AquaShine.LoadImage("image/com_button_01se.png"),
	
	FontConfig = AquaShine.LoadFont("MTLmr3m.ttf", 30),
	FontDesc = AquaShine.LoadFont("MTLmr3m.ttf", 22),
	DescImage = AquaShine.LoadImage("image/com_win_42.png"),
}

local SettingsList = {
	AUTOMODE = {
		before = AquaShine.LoadConfig("AUTOPLAY", 0),
		after = AquaShine.LoadConfig("AUTOPLAY", 0)
	},
	BACKGROUND_IMAGE = {
		before = AquaShine.LoadConfig("BACKGROUND_IMAGE", 11),
		after = AquaShine.LoadConfig("BACKGROUND_IMAGE", 11)
	},
	NOTE_STYLE = {
		before = AquaShine.LoadConfig("NOTE_STYLE", 1),
		after = AquaShine.LoadConfig("NOTE_STYLE", 2)
	},
	NOTE_SPEED = {
		before = AquaShine.LoadConfig("NOTE_SPEED", 800),
		after = AquaShine.LoadConfig("NOTE_SPEED", 800)
	}
}
Settings.Background = AquaShine.LoadImage("image/liveback_"..SettingsList.BACKGROUND_IMAGE.after..".png")

local MouseState = {0, 0, false}	-- x, y, is click?
local DescContentX = 464 + 20
local DescContentY = 236 + 20

local plus = AquaShine.LoadImage("image/com_etc_204.png")
local minus = AquaShine.LoadImage("image/com_etc_205.png")

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
		OnButton = AquaShine.LoadImage("image/set_button_14.png"),
		OnButtonSe = AquaShine.LoadImage("image/set_button_14se.png"),
		OffButton = AquaShine.LoadImage("image/set_button_15.png"),
		OffButtonSe = AquaShine.LoadImage("image/set_button_15se.png"),
	}
}

-- Usual configuration settings
function Settings.Start()
	for n, v in pairs(Settings.Config) do
		Settings.CurrentConfig[n] = AquaShine.LoadConfig(n, v)
	end	
end

function Settings.Update(deltaT)
	--Buttons
	setAutomodeButtons()
	setNotesButtons()
end

function Settings.Draw(deltaT)
	AquaShine.SetScissor(0, 0, 960, 640)
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
	
	if
		MouseState[3] and
		MouseState[1] >= 124 and MouseState[1] <= 190 and
		MouseState[2] >= 55 and MouseState[2] <= 65
	then
		-- Draw se
		--love.graphics.draw(ConfigList[1].OnButtonSe)
		love.graphics.draw(ConfigList[1].OnButtonSe, 185, 60)
	else
		-- Draw normal
		--love.graphics.draw(ConfigList[1].OnButton)
		love.graphics.draw(ConfigList[1].OnButton, 185, 60)
	end

	-- Draw label
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("Settings", 95, 13)
	love.graphics.setColor(255, 255, 255, 255)
	
	printSettings()
	AquaShine.ClearScissor()
end

function Settings.MousePressed(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = true
end

function Settings.MouseMoved(x, y)
	MouseState[1], MouseState[2] = x, y
end

function Settings.MouseReleased(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = false
	
	print("DEBUG: X:"..x.." Y:"..y)

	if x >= 0 and x <= 86 and y >= 0 and y <= 58 then
		-- Exit settings
		AquaShine.LoadEntryPoint("main_menu.lua")
	end

	-- Apply changes
	if (x >= 752 and x <= 890) and (y >= 20 and y <= 85) then
		changeSettings()
		print("Settings changed!")
	end
	-- Set automode as ON
	if (x >= 215 and x <= 270) and (y >= 70 and y <= 130) then
		SettingsList.AUTOMODE.after = 1
		love.graphics.draw(ConfigList[1].OnButton, 185, 60)
		love.graphics.draw(ConfigList[1].OffButtonSe, 275, 61)
		print("Before: "..SettingsList.AUTOMODE.after.."Automode = 1")
	end

	-- Set automode as OFF
	if (x >= 300 and x <= 355) and (y >= 65 and y <= 130) then
		SettingsList.AUTOMODE.after = 0
		love.graphics.draw(ConfigList[1].OnButtonSe, 185, 61)
		love.graphics.draw(ConfigList[1].OffButton, 275, 60)
		print("Automode = 0")
	end

	-- Set 5.0 as ON
	if (x >= 215 and x <= 270) and (y >= 310 and y <= 375) then
		SettingsList.NOTE_STYLE.after = 2
		print("5.0 Mode = ON")
	end

	-- Set 5.0 as OFF
	if (x >= 300 and x <= 355) and (y >= 310 and y <= 375) then
		SettingsList.NOTE_STYLE.after = 1
		print("5.0 Mode = OFF")
	end

	-- Remove 100 as note speed
	if (x >= 280 and x <= 305) and (y >= 245 and y <= 275) then
		if SettingsList.NOTE_SPEED.after > 400 then
			SettingsList.NOTE_SPEED.after = SettingsList.NOTE_SPEED.after - 100
		end
		print("Speed = "..SettingsList.NOTE_SPEED.after)
	end

	-- Add 100 as note speed
	if (x >= 395 and x <= 420) and (y >= 245 and y <= 275) then
		if SettingsList.NOTE_SPEED.after < 4500 then
			SettingsList.NOTE_SPEED.after = SettingsList.NOTE_SPEED.after + 100
		end
		print("Speed = "..SettingsList.NOTE_SPEED.after)
	end

	-- Remove 100 as note speed
	if (x >= 280 and x <= 305) and (y >= 170 and y <= 190) then
		if SettingsList.BACKGROUND_IMAGE.after > 1 then
			SettingsList.BACKGROUND_IMAGE.after = SettingsList.BACKGROUND_IMAGE.after - 1
		end
		print("Image = "..SettingsList.BACKGROUND_IMAGE.after)
		Settings.Background = AquaShine.LoadImage(string.format("image/liveback_%d.png", SettingsList.BACKGROUND_IMAGE.after))
	end

	-- Add 100 as note speed
	if (x >= 395 and x <= 420) and (y >= 170 and y <= 190) then
		if SettingsList.BACKGROUND_IMAGE.after < 12 then
			SettingsList.BACKGROUND_IMAGE.after = SettingsList.BACKGROUND_IMAGE.after + 1
		end
		print("Image = "..SettingsList.BACKGROUND_IMAGE.after)
		Settings.Background = AquaShine.LoadImage(string.format("image/liveback_%d.png", SettingsList.BACKGROUND_IMAGE.after))
	end

	--Other
end

local set_button_19 = AquaShine.LoadImage("assets/image/ui/set_button_19.png")
local set_button_19se = AquaShine.LoadImage("assets/image/ui/set_button_19se.png")
function printSettings()
	--Apply
	--Button
	if MouseState[3] and
		MouseState[1] >= 750 and MouseState[2] >= 20 and
		MouseState[1] < 894 and MouseState[2] < 78
	then
		love.graphics.draw(set_button_19se, 750, 20)
	else
		love.graphics.draw(set_button_19, 750, 20)
	end

	--Autoplay
	--Label
	love.graphics.draw(Settings.BackImage, -98, 80)
	--Text
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("Autoplay", 95, 93)
	love.graphics.setColor(255, 255, 255, 255)
	--Button
	setAutomodeButtons()

	--Background image ID
	--Label
	love.graphics.draw(Settings.BackImage, -38, 160)
	--Text
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("Background ID", 95, 173)
	love.graphics.setColor(255, 255, 255, 255)
	--Speed indicator
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print(SettingsList.BACKGROUND_IMAGE.after, 350, 170)
	love.graphics.setColor(255, 255, 255, 255)
	--Button
	love.graphics.draw(minus, 284, 170)
	love.graphics.draw(plus, 400, 170)

	--Speed Notes
	--Label
	love.graphics.draw(Settings.BackImage, -38, 240)
	--Text
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("Notes Speed", 95, 253)
	love.graphics.setColor(255, 255, 255, 255)
	--Speed indicator
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print(SettingsList.NOTE_SPEED.after, 335, 253)
	love.graphics.setColor(255, 255, 255, 255)
	--Button
	--Button
	love.graphics.draw(minus, 284, 250)
	love.graphics.draw(plus, 400, 250)

	--5.0 notes icon
	--Label
	love.graphics.draw(Settings.BackImage, -98, 320)
	--Text
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0, 255)
	love.graphics.print("5.0 Notes", 95, 333)
	love.graphics.setColor(255, 255, 255, 255)
	--Button
	setNotesButtons()
end

function setAutomodeButtons()
	if SettingsList.AUTOMODE.after == 0 then
		love.graphics.draw(ConfigList[1].OnButton, 185, 60)
		love.graphics.draw(ConfigList[1].OffButtonSe, 275, 61)
	else
		love.graphics.draw(ConfigList[1].OnButtonSe, 185, 61)
		love.graphics.draw(ConfigList[1].OffButton, 275, 60)
	end
end

function setNotesButtons()
	if SettingsList.NOTE_STYLE.after == 1 then
		love.graphics.draw(ConfigList[1].OnButton, 185, 300)
		love.graphics.draw(ConfigList[1].OffButtonSe, 275, 301)
	else
		love.graphics.draw(ConfigList[1].OnButtonSe, 185, 301)
		love.graphics.draw(ConfigList[1].OffButton, 275, 300)
	end
end

function changeSettings()
	if not(SettingsList.AUTOMODE.before == SettingsList.AUTOMODE.after) then
		AquaShine.SaveConfig("AUTOPLAY", SettingsList.AUTOMODE.after)
		SettingsList.AUTOMODE.before = SettingsList.AUTOMODE.after
		
		print("Changed: AUTOPLAY")
	end
	if not(SettingsList.BACKGROUND_IMAGE.before == SettingsList.BACKGROUND_IMAGE.after) then
		AquaShine.SaveConfig("BACKGROUND_IMAGE", SettingsList.BACKGROUND_IMAGE.after)
		SettingsList.BACKGROUND_IMAGE.before = SettingsList.BACKGROUND_IMAGE.after
		
		print("Changed: BACKGROUND_IMAGE")
	end
	if not(SettingsList.NOTE_STYLE.before == SettingsList.NOTE_STYLE.after) then
		AquaShine.SaveConfig("NOTE_STYLE", SettingsList.NOTE_STYLE.after)
		SettingsList.NOTE_STYLE.before = SettingsList.NOTE_STYLE.after
		print("Changed: NOTE_STYLE")
	end
	if not(SettingsList.NOTE_SPEED.before == SettingsList.NOTE_SPEED.after) then
		AquaShine.SaveConfig("NOTE_SPEED", SettingsList.NOTE_SPEED.after)
		SettingsList.NOTE_SPEED.before = SettingsList.NOTE_SPEED.after
		
		print("Changed: NOTE_SPEED")
	end
end
return Settings
