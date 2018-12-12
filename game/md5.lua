-- MD5 layer
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local md5fb = require("libs.md5")
local md5impl
local md5implfb

local function isData(t)
	return type(t) == "userdata" and t:typeOf("Data")
end

function md5implfb(code)
	if type(code) == "userdata" and code:typeOf("Data") then
		return md5fb.sum(code:getString())
	else
		return md5fb.sum(code)
	end
end
md5impl = md5implfb

if love._version >= "11.0" then
	function md5impl(code)
		return love.data.hash("md5", code)
	end
end

return function(code)
	local len = isData(code) and code:getSize() or #code
	-- https://bitbucket.org/rude/love/issues/1453
	-- https://bitbucket.org/rude/love/pull-requests/117
	-- LOVE 11.2 and earlier produces wrong hash for
	-- data that is 56 + 64k bytes long (k = 0, 1, 2, ...).
	-- In that case, keep using kikito's MD5 implementation
	if len % 64 == 56 and love._version <= "11.2" then
		return md5implfb(code)
	else
		return md5impl(code)
	end
end
