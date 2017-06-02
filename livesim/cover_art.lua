-- Album cover art
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local tween = require("tween")
local CoverArt = {CoverData = {}}

local ElapsedTime = 0
local TitleFont = AquaShine.LoadFont("MTLmr3m.ttf", 40)
local ArrFont = AquaShine.LoadFont("MTLmr3m.ttf", 16)
local Imagescale
local FirstTrans = {imageopacity = 0, textpos = 0, textopacity = 255}
local FirstTransTween = tween.new(233, FirstTrans, {imageopacity = 255, textpos = 480})
local TextAura = {textpos = 480, opacity = 127}
local TextAuraTween = tween.new(667, TextAura, {textpos = 580, opacity = 0})
local SecondTransTween = tween.new(333, FirstTrans, {imageopacity = 0, textopacity = 0})

local FirstTransComplete
local SecondTransComplete
local TextAuraComplete	

local drawtext = love.graphics.print
local draw = love.graphics.draw
local setFont = love.graphics.setFont
local setColor = love.graphics.setColor

local TitleWidth
local ArrWidth
local RandomFrame

function CoverArt.Initialize(cover_data)
	CoverArt.CoverData = cover_data
	Imagescale = {
		400 / cover_data.image:getWidth(),
		400 / cover_data.image:getHeight()
	}
	TitleWidth = TitleFont:getWidth(cover_data.title)
	
	if cover_data.arrangement then
		ArrWidth = ArrFont:getWidth(cover_data.arrangement)
	end
	
	if DEPLS.NoteRandomized then
		RandomFrame = AquaShine.LoadImage("assets/image/live/l_win_32.png")
	end
end

function CoverArt.Update(deltaT)
	ElapsedTime = ElapsedTime + deltaT
	FirstTransComplete = FirstTransTween:update(deltaT)
	
	if FirstTransComplete then
		TextAuraComplete = TextAuraTween:update(deltaT)
	end
	
	if ElapsedTime >= 2833 then
		SecondTransComplete = SecondTransTween:update(deltaT)
	end
end

function CoverArt.Draw()
	setFont(TitleFont)
	setColor(0, 0, 0, FirstTrans.textopacity * 0.5)
	drawtext(CoverArt.CoverData.title, FirstTrans.textpos - 2 - TitleWidth * 0.5, 507)
	drawtext(CoverArt.CoverData.title, FirstTrans.textpos + 2 - TitleWidth * 0.5, 509)
	setColor(255, 255, 255, FirstTrans.textopacity)
	drawtext(CoverArt.CoverData.title, FirstTrans.textpos - TitleWidth * 0.5, 508)
	
	if FirstTransComplete and not(TextAuraComplete) then
		setColor(0, 0, 0, TextAura.opacity * 0.5)
		drawtext(CoverArt.CoverData.title, TextAura.textpos - 2 - TitleWidth * 0.5, 507)
		drawtext(CoverArt.CoverData.title, TextAura.textpos + 2 - TitleWidth * 0.5, 509)
		setColor(255, 255, 255, TextAura.opacity)
		drawtext(CoverArt.CoverData.title, TextAura.textpos - TitleWidth * 0.5, 508)
		setColor(255, 255, 255, FirstTrans.textopacity)
	end
	
	if CoverArt.CoverData.arrangement then
		setFont(ArrFont)
		setColor(0, 0, 0, FirstTrans.textopacity * 0.5)
		drawtext(CoverArt.CoverData.arrangement, FirstTrans.textpos - 1 - ArrWidth * 0.5, 553)
		drawtext(CoverArt.CoverData.arrangement, FirstTrans.textpos + 1 - ArrWidth * 0.5, 555)
		setColor(255, 255, 255, FirstTrans.textopacity)
		drawtext(CoverArt.CoverData.arrangement, FirstTrans.textpos - ArrWidth * 0.5, 554)
		
		if FirstTransComplete and not(TextAuraComplete) then
			setColor(0, 0, 0, TextAura.opacity * 0.5)
			drawtext(CoverArt.CoverData.arrangement, TextAura.textpos - 1 - ArrWidth * 0.5, 553)
			drawtext(CoverArt.CoverData.arrangement, TextAura.textpos + 1 - ArrWidth * 0.5, 555)
			setColor(255, 255, 255, TextAura.opacity)
			drawtext(CoverArt.CoverData.arrangement, TextAura.textpos - ArrWidth * 0.5, 554)
		end
	end
	
	setColor(255, 255, 255, FirstTrans.imageopacity)
	draw(CoverArt.CoverData.image, 280, 80, 0, Imagescale[1], Imagescale[2])
	if RandomFrame then
		draw(RandomFrame, 280, 80, 0, 400 / 272)
	end
	setColor(255, 255, 255, 255)
end

return CoverArt
