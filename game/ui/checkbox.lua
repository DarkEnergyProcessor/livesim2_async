-- Checkbox
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local gui = require("libs.fusion-ui")
local assetCache = require("asset_cache")

local checkbox = {init = false}
local checkboxClass = {}
checkboxClass.checked = nil
checkboxClass.font = nil

function checkboxClass.__index(a, var)
	return rawget(checkboxClass, var) or gui.checkbox[var]
end

function checkboxClass.new(state)
	return setmetatable({
		state = not(not(state)),
	}, checkboxClass)
end

function checkboxClass.getSize()
	return 24, 24
end

function checkboxClass:render(x, y, w, h, _, style)
	style:drawBackground(x, y, w, h)

	if self.state then
		gui.platform.setColor(style.foregroundColor)
		gui.platform.draw(checkboxClass.checked, x + 12, y + 14, 0, 1, 1, 12, 14)
	end

	gui.platform.setStencilTest()
end

local defStyle = {
	backgroundImage = nil,
	backgroundSize = 'center',
	foregroundColor = {255, 255, 255, 255},
	backgroundColor = {0, 0, 0, 0},
	backgroundImageColor = {255, 255, 255, 255},
}

local function initialize()
	if not(checkbox.init) then
		local images = assetCache.loadMultipleImages({
			"assets/image/ui/com_etc_292.png",
			"assets/image/ui/com_etc_293.png"
		})
		checkboxClass.font = assetCache.loadFont("fonts/MTLmr3m.ttf", 22)
		defStyle.backgroundImage, checkboxClass.checked = images[1], images[2]
		checkbox.init = true
	end
end

function checkbox.new(checked, onchange)
	initialize()

	local element = gui.element.newElement("checkbox", checked, defStyle)
	element.type = checkboxClass.new(checked)
	element:releaseStyle()

	if onchange then
		element:addEventListener("changed", onchange)
	end

	return element
end

function checkbox.draw(element, x, y)
	return element:draw(x-4, y, 28, 24)
end

return checkbox
