-- Lily version wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local log = require("logging")

if love._version >= "11.0" then
	local lily = require("libs.lily.v3.lily")
	log.debugf("lily", "using version 3 (%s)", lily._VERSION)
	return lily
else
	local lily = require("libs.lily.v2.lily")
	log.debugf("lily", "using version 2 (%s)", lily._VERSION)
	return lily
end
