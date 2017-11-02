-- AquaShine error handler entry point
-- Part of Live Simulator: 2
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local ErrorHandler = {}

function ErrorHandler.Start(arg)
	ErrorHandler.Msg = assert(arg[1])
	
	love.graphics.setFont(AquaShine.LoadFont(nil, 14))
end

function ErrorHandler.Update() end

function ErrorHandler.Draw()
	love.graphics.clear(40, 133, 220)
	love.graphics.print(ErrorHandler.Msg, 70, 70)
end

local ExecutionIsRestart = false
function ErrorHandler.KeyReleased(key)
	if key == "escape" then
		if love.window.showMessageBox("AquaShine loader", "Are you sure want to exit?", {"No", "Yes"}) == 2 then
			AquaShine.RestartExecution = false
			love.event.quit()
		end
	end
end

function ErrorHandler.MouseReleased()
	ErrorHandler.KeyReleased("escape")
end

function ErrorHandler.Quit()
	if ExecutionIsRestart == false then
		AquaShine.RestartExecution = false
	end
end	

return ErrorHandler
