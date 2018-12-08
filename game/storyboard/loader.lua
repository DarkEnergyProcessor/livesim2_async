-- Storyboard loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local storyboardLoader = {
	loaders = {
		yaml = require("game.storyboard.yamlstoryboard")
	}
}

local temp = {nil, nil, nil}
local function callTemp()
	return temp[1](temp[2], temp[3])
end

function storyboardLoader.load(type, data, info)
	if storyboardLoader.loaders[type] then
		temp[1] = storyboardLoader.loaders[type]
		temp[2], temp[3] = data, info
		local status, msg = xpcall(callTemp, debug.traceback)
		if status then
			return msg
		else
			return nil, msg
		end
	else
		return nil, "unknown storyboard format"
	end
end

return storyboardLoader
