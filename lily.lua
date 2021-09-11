-- Lily version wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local log = require("logging")
local Util = require("util")
local lily

if Util.compareLOVEVersion(11, 0) >= 0 then
	lily = require("libs.lily_single_v3")
	log.debugf("lily", "using version 3 (%s)", lily._VERSION)
else
	lily = require("libs.lily_single_v2")
	log.debugf("lily", "using version 2 (%s)", lily._VERSION)
end

return lily
