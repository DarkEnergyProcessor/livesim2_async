-- About screen
-- Part of Live Simulator: 2

local AquaShine = ...
local love = love
local AboutScreen = {}

local TextFont = AquaShine.LoadFont("MTLmr3m.ttf", 15)
local TitleFont = AquaShine.LoadFont("MTLmr3m.ttf", 60)
local TitleIcon = AquaShine.LoadImage("assets/image/icon/icon_128x128.png")
local Background = {AquaShine.LoadImage(
	"assets/image/background/liveback_12.png",
	"assets/image/background/b_liveback_012_01.png",
	"assets/image/background/b_liveback_012_02.png",
	"assets/image/background/b_liveback_012_03.png",
	"assets/image/background/b_liveback_012_04.png"
)}
local ExternalLicenses = love.filesystem.load("about_screen_license")()
local Text = [[
Written By:     AuahDark
Special Thanks: @yuyu0127_ for the SIF v5-style note images.
                @RayFirefist for the contribution to Live Simulator: 2
				/u/MilesElectric168 for the note randomizer algorithm
License:
The MIT License (MIT)
Copyright (c) 2039 Dark Energy Processor Corporation

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
	* FFmpeg (when available)  	License



LOVE Version:				  ]]..love._version..[[

Repository:					https://github.com/MikuAuahDark/livesim2
Live Simulator: 2 Version:	 ]].._G.DEPLS_VERSION

function AboutScreen.Start() end
function AboutScreen.Update() end

function AboutScreen.Draw()
	local mx, my = AquaShine.CalculateTouchPosition(love.mouse.getPosition())
	
	-- Background
	love.graphics.setColor(0.25, 0.25, 0.25)
	love.graphics.draw(Background[1])
	love.graphics.draw(Background[2], -88, 0)
	love.graphics.draw(Background[3], 960, 0)
	love.graphics.draw(Background[4], 0, -43)
	love.graphics.draw(Background[5], 0, 640)
	love.graphics.setColor(1, 1, 1)
	
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
			love.graphics.setColor(0, 0, 0, 0.75)
			love.graphics.rectangle("fill", -88, -43, 1136, 726)
			love.graphics.setColor(1, 1, 1)
			love.graphics.print(a[3], 5, 150)
			
			break
		end
	end
end

function AboutScreen.KeyReleased(key, scancode)
	if key == "escape" then
		AquaShine.LoadEntryPoint(":main_menu")
	end
end

function AboutScreen.MouseReleased(x, y)
	if x >= 250 and y >= 598 and x < 578 and y < 630 then
		love.system.openURL("https://github.com/MikuAuahDark/livesim2")
	end
end

return AboutScreen, "About"
