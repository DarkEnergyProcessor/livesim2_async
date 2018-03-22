-- Pause menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local love = love
local PauseScreen = {
	Paused = -1,
	Font = AquaShine.LoadFont("MTLmr3m.ttf", 36),
	Counter = {AquaShine.LoadImage(
		"assets/image/live/score_num/l_num_01.png",
		"assets/image/live/score_num/l_num_02.png",
		"assets/image/live/score_num/l_num_03.png"
	)}
}

local PauseOverlay = AquaShine.Composition.Create {
	-- Pause overlay
	{
		x = 0, y = 0,
		draw = function(this)
			local name = DEPLS.NoteLoaderObject:GetName()
			
			love.graphics.setColor(0, 0, 0, 190 / 255)
			love.graphics.rectangle("fill", -88, -43, 1136, 726)
			love.graphics.setColor(1, 1, 1)
			love.graphics.setFont(PauseScreen.Font)
			love.graphics.print(name, 480 - PauseScreen.Font:getWidth(name) * 0.5, 192)
		end
	}
}

local PauseOverlayButton = AquaShine.Composition.Create {
	-- Resume button
	{
		x = 416, y = 300, w = 128, h = 48,
		_draw_text = function(this)
			love.graphics.setColor(1, 1, 1, 0.5)
			love.graphics.setFont(PauseScreen.Font)
			love.graphics.print("Resume", 13, 6)
		end,
		draw = function(this)
			love.graphics.setColor(0, 138 / 255, 1, 0.5)
			love.graphics.rectangle("fill", 0, 0, this.w, this.h)
			return this:_draw_text()
		end,
		draw_se = function(this)
			love.graphics.setColor(0.5, 197 / 255, 1, 0.5)
			love.graphics.rectangle("fill", 0, 0, this.w, this.h)
			love.graphics.setColor(0, 138 / 255, 1, 0.5)
			love.graphics.rectangle("line", 0, 0, this.w, this.h)
			return this:_draw_text()
		end,
		click = function(this)
			PauseScreen.Paused = 3000	-- Set pause timeout
		end
	},
	-- Quit button
	{
		x = 416, y = 372, w = 128, h = 48,
		_draw_text = function(this)
			love.graphics.setColor(1, 1, 1, 0.5)
			love.graphics.setFont(PauseScreen.Font)
			love.graphics.print("Quit", 30, 6)
		end,
		draw = function(this)
			love.graphics.setColor(251 / 255, 148 / 255, 0, 0.5)
			love.graphics.rectangle("fill", 0, 0, this.w, this.h)
			return this:_draw_text()
		end,
		draw_se = function(this)
			love.graphics.setColor(251 / 255, 199 / 255, 125 / 255, 0.5)
			love.graphics.rectangle("fill", 0, 0, this.w, this.h)
			love.graphics.setColor(251 / 255, 148 / 255, 0, 0.5)
			love.graphics.rectangle("line", 0, 0, this.w, this.h)
			return this:_draw_text()
		end,
		click = function(this)
			return DEPLS.KeyReleased("escape")
		end
	},
	-- Restart button
	{
		x = 416, y = 444, w = 128, h = 48,
		_draw_text = function(this)
			love.graphics.setColor(1, 1, 1, 0.5)
			love.graphics.setFont(PauseScreen.Font)
			love.graphics.print("Restart", 3, 6)
		end,
		draw = function(this)
			love.graphics.setColor(1, 28/255, 124/255, 0.5)
			love.graphics.rectangle("fill", 0, 0, this.w, this.h)
			return this:_draw_text()
		end,
		draw_se = function(this)
			love.graphics.setColor(1, 113/255, 173/255, 0.5)
			love.graphics.rectangle("fill", 0, 0, this.w, this.h)
			love.graphics.setColor(1, 28/255, 124/255, 0.5)
			love.graphics.rectangle("line", 0, 0, this.w, this.h)
			return this:_draw_text()
		end,
		click = function(this)
			return DEPLS.KeyReleased("backspace")
		end
	}
}

function PauseScreen.Update(deltaT)
	-- 0 or -1 pause value is not considered as paused.
	if PauseScreen.Paused > 0 then
		if PauseScreen.Paused <= 3000 then
			-- Resume initiated. Decreaase counter
			PauseScreen.Paused = PauseScreen.Paused - deltaT
			
			if PauseScreen.Paused <= 0 then
				if PauseScreen.ResumeCallback then
					PauseScreen.ResumeCallback()
				end
				
				PauseScreen.ResumeCallback = nil
			end
		elseif PauseScreen.Paused == math.huge then
			-- Fully paused state
		end
	end
end

function PauseScreen.Draw()
	-- 0 or -1 pause value is not considered as paused.
	if PauseScreen.Paused > 0 then
		PauseOverlay:Draw()
		
		if PauseScreen.Paused <= 3000 then
			-- Draw pause counter
			love.graphics.setColor(1, 1, 1)
			love.graphics.draw(
				PauseScreen.Counter[math.max(math.ceil(PauseScreen.Paused * 0.001), 1)],
				480, 320, 0, 1.5, 1.5, 18, 19.5
			)
		elseif PauseScreen.Paused == math.huge then
			-- Fully paused state
			PauseOverlayButton:Draw()
		end
	end
end

function PauseScreen.MousePressed(x, y, button)
	if button == 1 and PauseScreen.Paused == math.huge then
		PauseOverlayButton:MousePressed(x, y)
	end
end

function PauseScreen.MouseMoved(x, y)
	if PauseScreen.Paused == math.huge then
		PauseOverlayButton:MouseMoved(x, y)
	end
end

function PauseScreen.MouseReleased(x, y, button)
	if button == 1 and PauseScreen.Paused == math.huge then
		PauseOverlayButton:MouseReleased(x, y)
	end
end

function PauseScreen.IsPaused()
	return PauseScreen.Paused > 0
end

function PauseScreen.IsFullyPaused()
	return PauseScreen.Paused == math.huge
end

function PauseScreen.InitiatePause(resume_cb)
	PauseScreen.Paused = math.huge
	PauseScreen.ResumeCallback = resume_cb
end

return PauseScreen
