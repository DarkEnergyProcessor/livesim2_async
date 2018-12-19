-- Beatmap probe
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local JSON = require("libs.JSON")

return function(f)
	-- Check if it's JSON
	if f:read(30):find("%s*[{|%[]") then
		f:seek(0)
		local data = f:read()
		local s = pcall(JSON.decode, JSON, data)
		if s then
			return true
		end
	end

	f:seek(0)
	local header = f:read(4)
	if header == "MThd" or (header == "live" and f:read(4) == "sim2") then
		-- MIDI or LS2
		return true
	end

	return false
end
