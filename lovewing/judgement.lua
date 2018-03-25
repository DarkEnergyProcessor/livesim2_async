-- Judgement (accuracy) text (Lovewing variant)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local DEPLS, AquaShine = ...
local love = require("love")
local tween = require("tween")

local Judgement = {}

local function makeJudgementText(text)
	local w, h = Judgement.Venera72:getWidth(text), Judgement.Venera72:getHeight()
	local out = love.graphics.newCanvas(w, h)

	love.graphics.push("all")
	love.graphics.setFont(Judgement.Venera72)
	love.graphics.setCanvas(out)
	love.graphics.clear()
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(text)
	love.graphics.pop()

	return out
end

local function div2(a, b)
	return {a * 0.5, b * 0.5}
end

local function init()
	Judgement.ET = 2000

	-- Initialize resource
	Judgement.Venera72 = AquaShine.LoadFont("Venera-700.otf", 68)
	Judgement.Data = {opacity = 0, scale = 0}
	Judgement.ShowTween = tween.new(50, Judgement.Data, {opacity = 1, scale = 1}, "outSine")
	Judgement.FadeoutTween = tween.new(200, Judgement.Data, {opacity = 0})

	-- Set to end
	Judgement.ShowTween:update(50)
	Judgement.FadeoutTween:update(200)

	-- Tap accuracy image, umm, canvas
	DEPLS.Images.Perfect = makeJudgementText("PERFECT")
	DEPLS.Images.Great = makeJudgementText("GREAT")
	DEPLS.Images.Good = makeJudgementText("GOOD")
	DEPLS.Images.Bad = makeJudgementText("BAD")
	DEPLS.Images.Miss = makeJudgementText("MISS")
	Judgement.Image = DEPLS.Images.Perfect

	-- Position
	Judgement.Center = {
		[DEPLS.Images.Perfect] = div2(DEPLS.Images.Perfect:getDimensions()),
		[DEPLS.Images.Great] = div2(DEPLS.Images.Great:getDimensions()),
		[DEPLS.Images.Good] = div2(DEPLS.Images.Good:getDimensions()),
		[DEPLS.Images.Bad] = div2(DEPLS.Images.Bad:getDimensions()),
		[DEPLS.Images.Miss] = div2(DEPLS.Images.Miss:getDimensions()),
	}

	-- Color
	Judgement.Color = {
		[DEPLS.Images.Perfect] = {1, 1, 1},
		[DEPLS.Images.Great] = {0, 1, 1},
		[DEPLS.Images.Good] = {1, 1, 153/255},
		[DEPLS.Images.Bad] = {1, 153/255, 153/255},
		[DEPLS.Images.Miss] = {187/255, 170/255, 1}
	}

	return Judgement
end


function Judgement.Update(deltaT)
	Judgement.ET = Judgement.ET + deltaT

	if Judgement.Replay then
		Judgement.ET = deltaT
		Judgement.ShowTween:reset()
		Judgement.FadeoutTween:reset()
		Judgement.Replay = false
	end

	Judgement.ShowTween:update(deltaT)

	if Judgement.ET > 170 then
		Judgement.FadeoutTween:update(deltaT)
	end

	-- To prevent overflow
	while Judgement.ET > 5000 do
		Judgement.ET = Judgement.ET - 4000
	end
end

function Judgement.Draw()
	if Judgement.ET < 500 then
		local c = assert(Judgement.Color[Judgement.Image], tostring(Judgement.Image))
		love.graphics.setColor(c[1], c[2], c[3], Judgement.Data.opacity * DEPLS.LiveOpacity)
		love.graphics.draw(
			Judgement.Image, 480, 320, 0,
			Judgement.Data.scale * DEPLS.TextScaling,
			Judgement.Data.scale * DEPLS.TextScaling,
			Judgement.Center[Judgement.Image][1],
			Judgement.Center[Judgement.Image][2]
		)
		love.graphics.setColor(1, 1, 1)
	end
end

return init()
