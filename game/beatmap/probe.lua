-- Beatmap probe
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local JSON = require("libs.JSON")

return function(f)
	local firstdata = f:read(30)
	-- Skip UTF-8 BOM uh
	if firstdata:find("\239\187\191", 1, true) then
		firstdata = firstdata:sub(4)
	end

	-- Check if it's JSON
	if firstdata:find("%s*[{|%[]") then
		f:seek(0)
		local data = f:read()
		local s = pcall(JSON.decode, JSON, data)
		if s then
			return true
		end
	end

	f:seek(0)
	local header = f:read(4)
	if header == "MThd" then
		-- MIDI
		return true
	elseif header == "live" then
		local header2 = f:read(4)
		if header2 == "sim2" or header2 == "sim3" then
			-- LS2/OVR
			return true
		end
	end

	return false
end
