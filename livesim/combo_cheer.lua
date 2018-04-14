-- Combo cheer (sparkling background)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local love = require("love")
local Yohane = require("Yohane")
local ComboCheer = {}

-- Combo range: 100-200, 200-300, 300+
local Steps = {"cut_01_loop_end", "cut_02_loop_end", "cut_03_loop_end"}
local CurrentStep = 1

-- Hack function to replace flash image. Violates Yohane public API
-- but I don't want to modify the Yohane API even more.
local function flashSetImage(flash, name, image)
	local this = getmetatable(flash)
	local flshname = "I"..name..".png.imag"

	for i = 0, #this.movieData do
		if this.movieData[i].name == flshname then
			this.movieData[i].imageHandle = image
			return
		end
	end
	error("Invalid name "..name)
end


local function init()
	-- Load base image
	ComboCheer.ef_350 = AquaShine.LoadImage("assets/flash/ui/live/img/ef_350.png")
	-- Load Playground flash file
	ComboCheer.FlashFile = Yohane.newFlashFromFilename("flash/live_combo_cheer.flsh", "ef_350")
	-- HACK: Use atlas instead of individual images
	-- This allows LOVE to do automatic batching.
	for i = 0, 9 do
		flashSetImage(
			ComboCheer.FlashFile,
			string.format("assets/flash/ui/live/img/ef_350_%03d", i),
			{ComboCheer.ef_350, love.graphics.newQuad(i * 77, 0, 77, 78, 770, 78)}
		)
	end
	return ComboCheer
end

function ComboCheer.Update(deltaT)
	if DEPLS.MinimalEffect then return end

	if DEPLS.Routines.ComboCounter.CurrentCombo >= 100 then
		if DEPLS.Routines.ComboCounter.CurrentCombo >= 300 and CurrentStep ~= 3 then
			CurrentStep = 3
			ComboCheer.FlashFile:jumpToLabel("cut_02_end")
			ComboCheer.FlashFile:jumpToLabel("cut_03_loop")
		elseif
			DEPLS.Routines.ComboCounter.CurrentCombo >= 200 and
			DEPLS.Routines.ComboCounter.CurrentCombo < 300 and
			CurrentStep ~= 2
		then
			CurrentStep = 2
			ComboCheer.FlashFile:jumpToLabel("cut_01_end")
			ComboCheer.FlashFile:jumpToLabel("cut_02_loop")
		end

		ComboCheer.FlashFile:update(deltaT)

		if ComboCheer.FlashFile:isFrozen() then
			ComboCheer.FlashFile:jumpToLabel(Steps[CurrentStep])
		end
	elseif CurrentStep > 1 then
		CurrentStep = 1
		ComboCheer.FlashFile:jumpToLabel("cut_03_loop")
		ComboCheer.FlashFile:jumpToLabel("cut_01_loop")
	end
end

function ComboCheer.Draw()
	if DEPLS.MinimalEffect then return end

	if DEPLS.Routines.ComboCounter.CurrentCombo >= 100 then
		ComboCheer.FlashFile:setOpacity(DEPLS.LiveOpacity * 255)
		ComboCheer.FlashFile:draw()
	end
end

return init()
