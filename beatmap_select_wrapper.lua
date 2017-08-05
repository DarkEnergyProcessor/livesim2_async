-- Beatmap selection wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...

if AquaShine.LoadConfig("BEATMAP_SELECT_CACHED", 0) == 1 then
	return assert(love.filesystem.load("beatmap_select2.lua"))(AquaShine)
else
	return assert(love.filesystem.load("beatmap_select.lua"))(AquaShine)
end
