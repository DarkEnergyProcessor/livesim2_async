-- Added score, update routine using the new EffectPlayer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local love = require("love")
local DEPLS, AquaShine = ...
local ScoreNode = {}

local _common_meta = {__index = ScoreNode}

local function init()
	ScoreNode.Font = AquaShine.GetCachedData(
		"score_list_add",
		love.graphics.newImageFont,
		"assets/image/live/score_num/addscore.png", "0123456789+", -5
	)

	return ScoreNode
end

function ScoreNode.Create(score)
	local out = {}

	out.score_info = {opacity = 1, scale = 1.125, x = 520}
	out.main_tween = tween.new(100, out.score_info, {x = 570, scale = 1})
	out.opacity_tween = tween.new(200, out.score_info, {opacity = 0})
	out.elapsed_time = 0
	out.text = love.graphics.newText(ScoreNode.Font, "+"..score)

	return setmetatable(out, _common_meta)
end

function ScoreNode.Update(this, deltaT)
	this.elapsed_time = this.elapsed_time + deltaT
	this.main_tween:update(deltaT)

	if this.elapsed_time >= 200 then
		this.opacity_tween:update(deltaT)
	end

	return this.score_info.opacity == 0
end

function ScoreNode.Draw(this)
	love.graphics.setColor(1, 1, 1, this.score_info.opacity * DEPLS.LiveOpacity)
	love.graphics.draw(
		this.text,
		this.score_info.x, 72, 0,
		this.score_info.scale, this.score_info.scale,
		0, 16
	)
end

return init()
