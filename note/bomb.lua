-- Star note bomb
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local Yohane = require("Yohane")
local notes_bomb = Yohane.newFlashFromFilename("flash/live_notes_bomb.flsh", "ef_317")

local NoteBombEffect = AquaShine.Class("Livesim2.NoteBomb")

function NoteBombEffect.Create(out, x, y)
	out.flash = notes_bomb:clone()
	out.x = x
	out.y = y
	out.flash:jumpToLabel("bomb")
end

function NoteBombEffect.Create(x, y)
	return NoteBombEffect(x, y)
end

function NoteBombEffect:Update(deltaT)
	if not(self.flash:isFrozen()) then
		self.flash:update(deltaT)

		return false
	else
		return true
	end
end

function NoteBombEffect:Draw()
	self.flash:draw(self.x, self.y)
end

return NoteBombEffect
