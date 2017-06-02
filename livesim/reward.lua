-- Result screen. Original by RayFirefist. Edited by AuahDark
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = love
local DEPLS, AquaShine = ...
local tween = require("tween")
local ResultScreen = {}

-- UI Stuff
local Font = AquaShine.LoadFont("MTLmr3m.ttf", 36)

local comboWin = AquaShine.LoadImage("assets/image/live/l_win_07.png")
local scoreLogo = AquaShine.LoadImage("assets/image/live/l_etc_09.png")
local comboLogo = AquaShine.LoadImage("assets/image/live/l_etc_08.png")
local perfectLogo = AquaShine.LoadImage("assets/image/live/l_etc_11.png")
local greatLogo = AquaShine.LoadImage("assets/image/live/l_etc_12.png")
local goodLogo = AquaShine.LoadImage("assets/image/live/l_etc_13.png")
local badLogo = AquaShine.LoadImage("assets/image/live/l_etc_14.png")
local missLogo = AquaShine.LoadImage("assets/image/live/l_etc_15.png")
local liveClearLogo = AquaShine.LoadImage("assets/image/live/ef_330_000_1.png")

local combo

local Status = {Opacity = 0}
Status.Tween = tween.new(1000, Status, {Opacity = 255})

function ResultScreen.Update(deltaT)
	if not(combo) then
		local ninfo = DEPLS.NoteManager
		
		combo = {
			Perfect = string.format("%04d", ninfo.Perfect),
			Great = string.format("%04d", ninfo.Great),
			Good = string.format("%04d", ninfo.Good),
			Bad = string.format("%04d", ninfo.Bad),
			Miss = string.format("%04d", ninfo.Miss),
			MaxCombo = string.format("%04d", ninfo.HighestCombo)
		}
	end
	
	ResultScreen.CanExit = Status.Tween:update(deltaT)
end

function ResultScreen.Draw()
	if not(combo) then return end
	
	love.graphics.setFont(Font)
	love.graphics.setColor(0, 0, 0, Status.Opacity * 0.75)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	love.graphics.setColor(255, 255, 255, Status.Opacity)
	love.graphics.draw(comboWin, 127, 400, 0, 1.25, 1.25)
	love.graphics.draw(scoreLogo, 150, 555)
	love.graphics.draw(comboLogo, 530, 555)
	love.graphics.draw(perfectLogo, 150, 420, 0, 0.75, 0.75)
	love.graphics.draw(greatLogo, 300, 420, 0, 0.75, 0.75)
	love.graphics.draw(goodLogo, 440, 420, 0, 0.75, 0.75)
	love.graphics.draw(badLogo, 580, 420, 0, 0.75, 0.75)
	love.graphics.draw(missLogo, 700, 420, 0, 0.75, 0.75)
	love.graphics.draw(liveClearLogo, 480, 5, 0, 0.75, 0.75, 250, 0)

	love.graphics.setColor(0, 0, 0, Status.Opacity)
	love.graphics.print(combo.Perfect, 150, 460)
	love.graphics.print(combo.Great, 300, 460)
	love.graphics.print(combo.Good, 440, 460)
	love.graphics.print(combo.Bad, 580, 460)
	love.graphics.print(combo.Miss, 700, 460)
	love.graphics.print(DEPLS.Routines.ScoreUpdate.CurrentScore, 300, 550)
	love.graphics.print(combo.MaxCombo, 700, 550)
	love.graphics.setColor(255, 255, 255)
end

return ResultScreen
