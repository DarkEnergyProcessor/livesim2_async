-- Perfect node animation with new DEPLS routine architecture
local tween = require("tween")
local DEPLS = ...
local PerfectNode = {}

local et = 500
local perfect_data = {opacity = 0, scale = 0}
local perfect_tween = tween.new(50, perfect_data, {opacity = 255, scale = 2}, "outSine")
local perfect_tween_fadeout = tween.new(200, perfect_data, {opacity = 0})

perfect_tween:update(50)
perfect_tween_fadeout:update(200)

function PerfectNode.Update(deltaT)
	et = et + deltaT
	
	if PerfectNode.Replay then
		et = deltaT
		perfect_tween:reset()
		perfect_tween_fadeout:reset()
		PerfectNode.Replay = false
	end
	
	perfect_tween:update(deltaT)
	
	if et > 200 then
		perfect_tween_fadeout:update(deltaT)
	end
	
	-- To prevent overflow
	if et > 5000 then
		et = et - 4000
	end
end

local setColor = love.graphics.setColor
local draw = love.graphics.draw
function PerfectNode.Draw()
	if et < 500 then
		setColor(255, 255, 255, perfect_data.opacity * DEPLS.LiveOpacity / 255)
		draw(PerfectNode.Image, 480, 320, 0, perfect_data.scale, perfect_data.scale,
			PerfectNode.Center[PerfectNode.Image][1], PerfectNode.Center[PerfectNode.Image][2])
		setColor(255, 255, 255, 255)
	end
end

return PerfectNode
