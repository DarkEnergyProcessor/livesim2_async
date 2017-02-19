local AboutScreen = {}

local TextFont = FontManager.GetFont("MTLmr3m.ttf", 15)
local TitleFont = FontManager.GetFont("MTLmr3m.ttf", 60)
local TitleIcon = love.graphics.newImage("image/icon_128x128.png")
local Background = love.graphics.newImage("image/liveback_12.png")
local ExternalLicenses = loadstring(
	love.math.decompress(love.filesystem.newFileData("about_screen_license"), "zlib"),
	"about_screen_license"
)()
local Text = [[
Written By:		AuahDark
Assets From:	   Love Live! School Idol Festival and Sukufesu Simulator

License:

The MIT License (MIT)
Copyright (c) 2038 Dark Energy Processor Corporation

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated
documentation files (the "Software"), to deal in the Software without restriction, including without limitation the
rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit
persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR
OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

This Live Simulator uses Motoya L Maru font. License
This Live Simulator uses these external libraries:
	* tween.lua					License
	* JSON.lua				 	License
	* Lua FFT library		  	License
	* Yohane FLSH Abstraction  	License
	* Shelsha TEXB Loader	  	License




Repository:			https://github.com/MikuAuahDark/DEPLS
DEPLS2 Version:		]].._G.DEPLS_VERSION

function AboutScreen.Start() end
function AboutScreen.Update() end

function AboutScreen.Draw()
	local mx, my = CalculateTouchPosition(love.mouse.getPosition())
	
	-- Background
	love.graphics.setColor(64, 64, 64)
	love.graphics.draw(Background)
	love.graphics.setColor(255, 255, 255)
	
	-- Title
	love.graphics.setFont(TitleFont)
	love.graphics.draw(TitleIcon, 5, 0, 0, 0.9, 0.9)
	love.graphics.print("Live Simulator: 2", 140, 30)
	
	-- Text
	love.graphics.setFont(TextFont)
	love.graphics.print(Text, 5, 120)
	
	for i = 1, #ExternalLicenses do
		local a = ExternalLicenses[i]
		
		if mx >= a[1] and my >= a[2] and mx < a[1] + 56 and my < a[2] + 12 then
			love.graphics.setColor(0, 0, 0, 192)
			love.graphics.rectangle("fill", 0, 0, 960, 640)
			love.graphics.setColor(255, 255, 255)
			love.graphics.print(a[3], 5, 150)
			
			break
		end
	end
end

function love.keypressed(key, scancode, repeat_bit)
	if not(repeat_bit) and key == "escape" then
		LoadEntryPoint("main_menu.lua")
	end
end

return AboutScreen
