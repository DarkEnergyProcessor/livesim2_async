-- Live clear animation (incl. FULLCOMBO)

local DEPLS = ...
local Yohane = require("Yohane")
local LiveClear = {}

local ElapsedTime = 0
local isVoicePlayed = false
local isFLDetermined = false

function LiveClear.Update(deltaT)
	if not(isFCDetermined) then
		if
			DEPLS.NoteManager.Good == 0 and
			DEPLS.NoteManager.Bad == 0 and
			DEPLS.NoteManager.Miss == 0
		then
			-- Full Combo display for 2 seconds.
			ElapsedTime = 2000
		end
		
		isFCDetermined = true
	end
	
	if ElapsedTime > 0 then
		ElapsedTime = ElapsedTime - deltaT
		DEPLS.FullComboAnim:setOpacity(DEPLS.LiveOpacity)
		DEPLS.FullComboAnim:update(deltaT)
	else
		if DEPLS.Sound.LiveClear and not(isVoicePlayed) then
			DEPLS.Sound.LiveClear:play()
			isVoicePlayed = true
		end
		
		DEPLS.LiveShowCleared:setOpacity(DEPLS.LiveOpacity)
		DEPLS.LiveShowCleared:update(deltaT)
	end
end

function LiveClear.Draw()
	if ElapsedTime > 0 then
		DEPLS.FullComboAnim:draw(480, 320)
	else
		DEPLS.LiveShowCleared:draw(480, 320)
	end
end

return LiveClear
