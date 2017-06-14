-- Base storyboard object
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local function noop() end
local Storyboard = {_mt = {__index = {
	Initialize = noop,
	Draw = noop,
	SetAdditionalFiles = noop,
	Cleanup = noop,
	Callback = noop,
	Type = "StoryboardBase"
}}}

function Storyboard.CreateDummy()
	return (setmetatable({}, Storyboard._mt))
end

return Storyboard
