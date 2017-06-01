-- Combo cheer
-- Part of Live Simulator: 2

local DEPLS = ...
local Yohane = require("Yohane")
local ComboCheer = {}

local FlashFile = Yohane.newFlashFromFilename("flash/live_combo_cheer.flsh", "ef_350")

-- Combo range: 100-200, 200-300, 300+
local Steps = {"cut_01_loop_end", "cut_02_loop_end", "cut_03_loop_end"}
local CurrentStep = 1

function ComboCheer.Update(deltaT)
	if DEPLS.MinimalEffect then return end
	
	if DEPLS.Routines.ComboCounter.CurrentCombo >= 100 then
		if DEPLS.Routines.ComboCounter.CurrentCombo >= 300 and CurrentStep ~= 3 then
			CurrentStep = 3
			FlashFile:jumpToLabel("cut_02_end")
			FlashFile:jumpToLabel("cut_03_loop")
		elseif
			DEPLS.Routines.ComboCounter.CurrentCombo >= 200 and
			DEPLS.Routines.ComboCounter.CurrentCombo < 300 and
			CurrentStep ~= 2
		then
			CurrentStep = 2
			FlashFile:jumpToLabel("cut_01_end")
			FlashFile:jumpToLabel("cut_02_loop")
		end
		
		FlashFile:update(deltaT)
		
		if FlashFile:isFrozen() then
			FlashFile:jumpToLabel(Steps[CurrentStep])
		end
	elseif CurrentStep > 1 then
		CurrentStep = 1
		FlashFile:jumpToLabel("cut_03_loop")
		FlashFile:jumpToLabel("cut_01_loop")
	end
end

function ComboCheer.Draw()
	if DEPLS.MinimalEffect then return end
	
	if DEPLS.Routines.ComboCounter.CurrentCombo >= 100 then
		FlashFile:setOpacity(DEPLS.LiveOpacity)
		FlashFile:draw()
	end
end

return ComboCheer
