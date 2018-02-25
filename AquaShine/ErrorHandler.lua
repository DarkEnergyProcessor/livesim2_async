-- AquaShine error handler entry point
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local love = require("love")
local ErrorHandler = {}

function ErrorHandler.Start(arg)
	ErrorHandler.Msg = assert(arg[1])

	love.graphics.setFont(AquaShine.LoadFont(nil, 14))
end

function ErrorHandler.Update() end

function ErrorHandler.Draw()
	love.graphics.clear(0.1569, 0.5216, 0.8628)
	love.graphics.print(ErrorHandler.Msg, 70, 70)
end

local option = {"No", "Yes"}
function ErrorHandler.KeyReleased(key)
	if key == "escape" then
		if love.window.showMessageBox("AquaShine loader", "Are you sure want to exit?", option) == 2 then
			love.event.quit()
		end
	end
end

function ErrorHandler.KeyPressed(key)
	if key == "c" and love.keyboard.isDown("rctrl", "lctrl") then
		love.system.setClipboardText(ErrorHandler.Msg:sub(113))
	end
end

function ErrorHandler.MouseReleased(_, _, _, touch)
	if touch then
		return love.system.setClipboardText(ErrorHandler.Msg:sub(113))
	else
		return ErrorHandler.KeyReleased("escape")
	end
end

function ErrorHandler.Quit()
end

return ErrorHandler
