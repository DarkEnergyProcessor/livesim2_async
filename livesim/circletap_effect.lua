-- Circle tap effect routines using the new EffectPlayer
local tween = require("tween")
local DEPLS = ({...})[1]
local CircleTapEffect = {}

local _common_meta = {__index = CircleTapEffect}

--! @brief Circletap aftertap effect initialize function.
--! @param x The x position relative to center of the image
--! @param y The y position relative to center of the image
--! @param r The RGB red value. Defaults to 255
--! @param g The RGB green value. Defaults to 255
--! @param b The RGB blue value. Defaults to 255
function CircleTapEffect.Create(x, y, r, g, b)
	local out = {}
	
	out.r = r
	out.g = g
	out.b = b
	out.el_t = 0
	out.circle1_data = {}
	out.circle1_data.scale = 2
	out.circle1_data.opacity = 255
	out.circle2_data = {}
	out.circle2_data.scale = 2
	out.circle2_data.opacity = 255
	out.circle3_data = {}
	out.circle3_data.scale = 2
	out.circle3_data.opacity = 255
	out.stareff_data = {}
	out.stareff_data.opacity = 255
	
	do
		local temp = {}
		
		temp.scale = 3.5
		out.circle1_tween = tween.new(125, out.circle1_data, temp)
		out.circle2_tween = tween.new(200, out.circle2_data, temp)
		out.circle3_tween = tween.new(250, out.circle3_data, temp)
		
		temp = {}
		temp.opacity = 0
		out.circle1_tween_op = tween.new(125, out.circle1_data, temp, "inQuad")
		out.circle2_tween_op = tween.new(200, out.circle2_data, temp, "inQuad")
		out.circle3_tween_op = tween.new(250, out.circle3_data, temp, "inQuad")
		out.stareff_tween = tween.new(250, out.stareff_data, temp, "inQuad")
	end
	
	out.pos = {}
	out.pos[1] = x
	out.pos[2] = y
	
	return setmetatable(out, _common_meta)
end

function CircleTapEffect.Update(this, deltaT)
	local still_has_render = false
	this.el_t = this.el_t + deltaT
	
	if this.circle1_tween and this.circle1_tween:update(deltaT) == false then
		still_has_render = true
		
		this.circle1_tween_op:update(deltaT)
	else
		this.circle1_tween = nil
	end
	
	if this.circle2_tween and this.circle2_tween:update(deltaT) == false then
		still_has_render = true
		
		this.circle2_tween_op:update(deltaT)
	else
		this.circle2_tween = nil
	end
	
	if this.circle3_tween and this.circle3_tween:update(deltaT) == false then
		still_has_render = true
		
		this.circle3_tween_op:update(deltaT)
	else
		this.circle3_tween = nil
	end
	
	if this.el_t >= 75 and this.stareff_tween:update(deltaT) == false then
		still_has_render = true
	end
	
	-- Return false means keep updating
	return not(still_has_render)
end

local setColor = love.graphics.setColor
local draw = love.graphics.draw
function CircleTapEffect.Draw(this)
	local circle = DEPLS.Images.ef_316_001
	local liveop = DEPLS.LiveOpacity / 255
	
	if this.circle1_tween then
		setColor(this.r, this.g, this.b, this.circle1_data.opacity * liveop)
		draw(circle, this.pos[1], this.pos[2], 0, this.circle1_data.scale, this.circle1_data.scale, 37.5, 37.5)
	end
	
	if this.circle2_tween then
		setColor(this.r, this.g, this.b, this.circle2_data.opacity * liveop)
		draw(circle, this.pos[1], this.pos[2], 0, this.circle2_data.scale, this.circle2_data.scale, 37.5, 37.5)
	end
	
	if this.circle3_tween then
		setColor(this.r, this.g, this.b, this.circle3_data.opacity * liveop)
		draw(circle, this.pos[1], this.pos[2], 0, this.circle3_data.scale, this.circle3_data.scale, 37.5, 37.5)
	end
	
	setColor(this.r, this.g, this.b, this.stareff_data.opacity * liveop)
	draw(DEPLS.Images.ef_316_000, this.pos[1], this.pos[2], 0, 1.5, 1.5, 50, 50)
	setColor(255, 255, 255, 255)
end

return CircleTapEffect
