-- LOVE 11.0 screenshot implementation
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local util = require("util")
local screenshot = {
	list = {}
}

local function screenshotUpdateImpl() end

local function cleanListStartFrom(i, len)
	for j = i, len do
		screenshot.list[j] = nil
	end
end

function screenshot.update()
	return screenshotUpdateImpl()
end

if love._version <= "11.0" then
	function screenshotUpdateImpl()
		local len = #screenshot.list
		if len > 0 then
			local ss = love.graphics.newScreenshot()
			for i = 1, len do
				local obj = screenshot.list[i]
				local tobj = type(obj)

				if tobj == "string" then
					local ext = util.getExtension(obj):lower()
					ext = #ext > 0 and ext or "png"
					ss:encode(ext, obj)
				elseif tobj == "function" then
					local s, m = pcall(obj, ss)
					if not(s) then
						cleanListStartFrom(i, len)
						error(m)
					end
				elseif tobj == "userdata" and tobj.typeOf and tobj:typeOf("Channel") then
					obj:push(ss)
				end

				screenshot.list[i] = nil
			end
		end
	end

	function love.graphics.captureScreenshot(obj)
		local tobj = type(obj)
		if tobj == "string" or tobj == "function" or (tobj == "userdata" and tobj:typeOf("Channel")) then
			screenshot.list[#screenshot.list + 1] = obj
		end
	end
end

return screenshot
