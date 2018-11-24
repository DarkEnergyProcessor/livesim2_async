-- MD5 layer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

if love._version >= "11.0" then
	return function(code)
		return love.data.hash("md5", code)
	end
else
	local lib = require("libs.md5")
	return function(code)
		if type(code) == "userdata" and code:typeOf("Data") then
			return lib.sum(code:getString())
		else
			return lib.sum(code)
		end
	end
end
