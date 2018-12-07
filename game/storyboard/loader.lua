-- Storyboard loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local storyboardLoader = {
	loaders = {
		yaml = require("game.storyboard.yamlstoryboard")
	}
}

function storyboardLoader.load(type, data, info)
	if storyboardLoader.loaders[type] then
		local status, msg = pcall(storyboardLoader.loaders[type], data, info)
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
