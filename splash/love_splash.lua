-- LOVE 0.10.1 splash screen (fused only)
-- Demonstration of AquaShine.SetSplashScreen

local AquaShine = ...
local SplashScreen = {}
local o_ten_one = require("splash.o-ten-one")

function SplashScreen.OnDone()
	-- SplashScreen.NextArg is correspond to AquaShine.LoadEntryPoint
	AquaShine.LoadEntryPoint(SplashScreen.NextArg[1], SplashScreen.NextArg[2])
end

function SplashScreen.Start(arg)
	-- arg is correspond to AquaShine.LoadEntryPoint
	-- so store it somewhere else
	SplashScreen.NextArg = arg
	SplashScreen.Splash = o_ten_one()
	SplashScreen.Splash.onDone = SplashScreen.OnDone
end

function SplashScreen.Update(deltaT)
	return SplashScreen.Splash:update(deltaT * 0.001)
end

function SplashScreen.Draw()
	-- Since LOVE splash doesn't respect to AquaShine letterbox
	-- Push current stack and call origin
	love.graphics.push()
	love.graphics.origin()
	SplashScreen.Splash:draw()
	love.graphics.pop()
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
