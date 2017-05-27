-- Live Simulator: 2 Skill Popups
local DEPLS, AquaShine = ...
local tween = require("tween")
local lg = require("love.graphics")
local Yohane = require("Yohane")
local EffectPlayer = require("effect_player")
local SkillPopups = {IdolEffect = {}}

SkillPopups.FlashAnimation = Yohane.newFlashFromFilename("flash/live_cut_in.flsh")
SkillPopups.List = {}
SkillPopups.IdolEffectImage = {}
SkillPopups.EffectTitleImage = {}
SkillPopups.DirectionRarity = {}

-- Idol Effect Image
SkillPopups.IdolEffectImage.red = AquaShine.LoadImage("assets/image/live/ef_320_skill_001.png")
SkillPopups.IdolEffectImage.green = AquaShine.LoadImage("assets/image/live/ef_320_skill_010.png")
SkillPopups.IdolEffectImage.yellow = AquaShine.LoadImage("assets/image/live/ef_320_skill_002.png")
SkillPopups.IdolEffectImage.blue = AquaShine.LoadImage("assets/image/live/ef_320_skill_012.png")
SkillPopups.IdolEffectImage.purple = AquaShine.LoadImage("assets/image/live/ef_320_skill_006.png")

-- Effect Title Image
SkillPopups.EffectTitleImage.score_up = AquaShine.LoadImage("assets/image/live/score-up.png")
SkillPopups.EffectTitleImage.healer = AquaShine.LoadImage("assets/image/live/tairyoku.png")
SkillPopups.EffectTitleImage["tw+"] = AquaShine.LoadImage("assets/image/live/hantei-syo.png")
SkillPopups.EffectTitleImage["tw++"] = AquaShine.LoadImage("assets/image/live/hantei-dai.png")

-- Effect direction
SkillPopups.DirectionRarity.UR = "ef_307"
SkillPopups.DirectionRarity.SSR = "ef_308"
SkillPopups.DirectionRarity.SR = "ef_306"
SkillPopups.DirectionRarity.R = "ef_305"

local function make_idolcolor_tween()
	local a = {}
	local b = {}
	
	a.opacity = 255
	a.scale = 0.2
	b.opacity = 0
	b.scale = 4
	
	return (tween.new(700, a, b))
end

-- Idol effect for effect player
SkillPopups.IdolEffect.__index = SkillPopups.IdolEffect
function SkillPopups.IdolEffect.Create(unit_pos, image)
	local out = {}
	local info = {Opacity = 255, Scale = 0.2}
	
	out.Status = info
	out.Tween = tween.new(700, info, {Opacity = 0}, "inCubic")
	out.Tween2 = tween.new(700, info, {Scale = 4})
	out.Image = image
	out.X, out.Y = DEPLS.IdolPosition[unit_pos][1], DEPLS.IdolPosition[unit_pos][2]
	out.X, out.Y = out.X + 64, out.Y + 64
	
	return setmetatable(out, SkillPopups.IdolEffect)
end

function SkillPopups.IdolEffect.Update(out, deltaT)
	return out.Tween:update(deltaT) or out.Tween2:update(deltaT)
end

function SkillPopups.IdolEffect.Draw(out)
	love.graphics.setColor(255, 255, 255, out.Status.Opacity)
	love.graphics.draw(out.Image, out.X, out.Y, 0, out.Status.Scale, out.Status.Scale, 32, 32)
end

--! @brief Shows skill cut-in
--! @param unit_pos The unit position which one that triggers the skill
--! @param name The unit position effect color name
--! @param title Cut-in skill name
--! @param navi Transparent image of the cut-in
--! @param rarity Unit rarity. This determines the direction
--! @param audio Unit skill activation audio
--! @param force Always shows even if there's one in progress?
function SkillPopups.Spawn(unit_pos, name, title, navi, rarity, audio, force)
	-- one of it must be not nil. Audio is optional
	if name then
		EffectPlayer.Spawn(SkillPopups.IdolEffect.Create(unit_pos, assert(SkillPopups.IdolEffectImage[name], "Invalid idol effect color")))
	end
	
	if title and rarity and (#SkillPopups.List == 0 or force) then
		local out = {}
		
		out.Flash = SkillPopups.FlashAnimation:clone()
		out.Flash:setMovie(assert(SkillPopups.DirectionRarity[rarity:upper()], "Invalid rarity"))
		out.Flash:setImage("skill_text", assert(SkillPopups.EffectTitleImage[title], "Invalid skill text"))
		
		if navi then
			out.Flash:setImage("skill_chara", navi)
		end
		
		if audio then
			audio:play()
		end
		
		SkillPopups.List[#SkillPopups.List + 1] = out
	end
end

function SkillPopups.Update(deltaT)
	for i = #SkillPopups.List, 1, -1 do
		local x = SkillPopups.List[i]
		
		x.Flash:update(deltaT)
		
		if x.Flash:isFrozen() then
			table.remove(SkillPopups.List, i)
		end
	end
end

function SkillPopups.Draw()
	for i = 1, #SkillPopups.List do
		SkillPopups.List[i].Flash:draw(480, 320)
	end
end

return SkillPopups
