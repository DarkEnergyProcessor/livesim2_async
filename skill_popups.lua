-- DEPLS2 Skill Popups
local DEPLS = ({...})[1]
local tween = require("tween")
local lg = require("love.graphics")
local SkillPopups = {}

SkillPopups.List = {}
SkillPopups.IdolEffectImage = {}
SkillPopups.EffectTitleImage = {}

-- Idol Effect Image
SkillPopups.IdolEffectImage.red = lg.newImage("image/ef_320_skill_001.png")
SkillPopups.IdolEffectImage.green = lg.newImage("image/ef_320_skill_010.png")
SkillPopups.IdolEffectImage.yellow = lg.newImage("image/ef_320_skill_002.png")
SkillPopups.IdolEffectImage.blue = lg.newImage("image/ef_320_skill_012.png")
SkillPopups.IdolEffectImage.purple = lg.newImage("image/ef_320_skill_006.png")

-- Effect Title Image
SkillPopups.EffectTitleImage.score_up = lg.newImage("image/score-up.png")
SkillPopups.EffectTitleImage.healer = lg.newImage("image/tairyoku.png")
SkillPopups.EffectTitleImage["tw+"] = lg.newImage("image/hantei-syo.png")
SkillPopups.EffectTitleImage["tw++"] = lg.newImage("image/hantei-dai.png")

local function make_idolcolor_tween()
	local a = {}
	local b = {}
	
	a.opacity = 255
	a.scale = 0.2
	b.opacity = 0
	b.scale = 4
	
	return (tween.new(700, a, b))
end

local function make_navi_tween(direction)
	local a = {}	-- from
	local b = {}	-- tweens
	local c = {}	-- initialization
	
	-- Index 1 = showing
	-- Index 2 = slowdown
	-- Index 3 = end
	a[1] = {}
	a[2] = {}
	a[3] = {}
	
	if direction == "right" then
		c.x = 1440
		c.opacity = 0
		
		-- Showing
		a[1].x = 600
		a[1].opacity = 255
		
		-- slowdown
		a[2].x = 480
		a[2].opacity = 255
		
		-- end
		a[3].x = -480
		a[3].opacity = 0
		
		b[1] = tween.new(500, c, a[1])
		b[2] = tween.new(750, c, a[2])
		b[3] = tween.new(300, c, a[3])
	else
		c.x = -480
		c.opacity = 0
		
		-- Showing
		a[1].x = 360
		a[1].opacity = 255
		
		-- slowdown
		a[2].x = 480
		a[2].opacity = 255
		
		-- end
		a[3].x = 1440
		a[3].opacity = 0
		
		b[1] = tween.new(500, c, a[1])
		b[2] = tween.new(750, c, a[2])
		b[3] = tween.new(300, c, a[3])
	end
	
	return b
end

function SkillPopups.Spawn(direction, name, title, navi, audio, shadowing, force)
	-- direction must be left or right
	assert(direction == "left" or direction == "right", "Invalid direction")
	-- one of it must be not nil. Audio is optional
	assert(name or title or navi, "idol effect color, skill title, or navi must be non-nil")
	
	local out = {}
	
	if name then
		out.skill_image = assert(SkillPopups.EffectTitleImage[name], "Invalid idol effect color")
		out.skill_tween = make_idolcolor_tween()
	end
	
	if title then
		local a = {}
		local b = {}
		
		
	end
end