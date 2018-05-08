-- Live Simulator: 2 splash screen
-- Part of Live Simulator: 2
-- See copyright notice in main.lua
-- Demonstration of AquaShine.SetSplashScreen

local AquaShine = ...
local SplashScreen = {}
local ls2 = require("splash")

function SplashScreen.OnDone()
	-- SplashScreen.NextArg is correspond to AquaShine.LoadEntryPoint
	AquaShine.LoadEntryPoint(SplashScreen.NextArg[1], SplashScreen.NextArg[2])
end

function SplashScreen.Start(arg)
	-- arg is correspond to AquaShine.LoadEntryPoint
	-- so store it somewhere else
	SplashScreen.NextArg = arg
	SplashScreen.Splash = ls2()
	SplashScreen.Splash.onDone = SplashScreen.OnDone
end

function SplashScreen.Update(deltaT)
	return SplashScreen.Splash:update(deltaT * 0.001)
end

function SplashScreen.Draw()
	return SplashScreen.Splash:draw()
end

function SplashScreen.KeyPressed(key)
	if key == "escape" or key == "return" or key == "backspace" then
		return SplashScreen.Splash:skip()
	end
end

function SplashScreen.MousePressed()
	return SplashScreen.Splash:skip()
end

return SplashScreen
