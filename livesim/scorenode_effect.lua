-- Added score, update routine using the new EffectPlayer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local tween = require("tween")
local DEPLS = ...
local ScoreNode = {CanvasList = {}}

local _common_meta = {__index = ScoreNode}
local graphics = love.graphics

function ScoreNode.Create(score)
	local out = {}
	local Images = DEPLS.Images
	
	for i = 1, #ScoreNode.CanvasList do
		if ScoreNode.CanvasList[i].Used == false then
			out.score_canvas = ScoreNode.CanvasList[i]
			break
		end
	end
	
	if not(out.score_canvas) then
		local canvas = graphics.newCanvas(500, 32)
		local temp = {}
		
		temp.Canvas = canvas
		out.score_canvas = temp
		ScoreNode.CanvasList[#ScoreNode.CanvasList + 1] = temp
	end
	
	out.score_canvas.Used = true
	out.score_info = {opacity = 255, scale = 1.125, x = 520}
	out.main_tween = tween.new(100, out.score_info, {x = 570, scale = 1})
	out.opacity_tween = tween.new(200, out.score_info, {opacity = 0})
	out.elapsed_time = 0
	
	-- Draw all in canvas
	graphics.push("all")
	graphics.setCanvas(out.score_canvas.Canvas)
	graphics.clear()
	graphics.setBlendMode("alpha", "premultiplied")
	graphics.setColor(255, 255, 255, DEPLS.LiveOpacity)
	graphics.draw(Images.ScoreNode.Plus)
	
	do
		local i = 1
		for w in tostring(score):gmatch("%d") do
			graphics.draw(Images.ScoreNode[tonumber(w)], i * 24, 0)
			i = i + 1
		end
	end
	
	graphics.pop()
	return (setmetatable(out, _common_meta))
end

function ScoreNode.Update(this, deltaT)
	this.elapsed_time = this.elapsed_time + deltaT
	this.main_tween:update(deltaT)
	
	if this.elapsed_time >= 200 then
		this.opacity_tween:update(deltaT)
	end
	
	if this.elapsed_time >= 450 then
		this.score_canvas.Used = false
		return true
	end
	
	return false
end

function ScoreNode.Draw(this)
	graphics.setColor(255, 255, 255, this.score_info.opacity * DEPLS.LiveOpacity / 255)
	graphics.draw(this.score_canvas.Canvas, this.score_info.x, 72, 0, this.score_info.scale, this.score_info.scale, 0, 16)
	graphics.setColor(255, 255, 255, 255)
end

return ScoreNode
