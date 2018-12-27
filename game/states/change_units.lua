-- Change Units menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local async = require("async")
local color = require("color")
local setting = require("setting")
local util = require("util")
local mainFont = require("font")
local lily = require("lily")
local L = require("language")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local imageButton = require("game.ui.image_button")
local selectButton = require("game.ui.select_button")

local mipmap = {mipmaps = true}

local changeUnits = gamestate.create {
	images = {
		dummyUnit = {"assets/image/dummy.png", mipmap}
	},
	fonts = {},
	audios = {}
}

local idolPosition = {
	{816+64, 96+64 },
	{785+64, 249+64},
	{698+64, 378+64},
	{569+64, 465+64},
	{416+64, 496+64},
	{262+64, 465+64},
	{133+64, 378+64},
	{46+64 , 249+64},
	{16+64 , 96+64 },
}

local function constructCenteredText(font, start, text)
	local t = love.graphics.newText(font)
	for i = 1, 0, -1 do
		local c = 255 - i * 255
		local ct = {color.compat(c, c, c, 1)}
		local h = font:getHeight()

		local j = 0
		for k in text:gmatch("[^\n]+") do
			local w = font:getWidth(k)
			t:add({ct, k}, 480 - w * 0.5 + i, start + j * h + i)
			j = j + 1
		end
	end

	return t
end

local function updateCurrentMode(text, button, mode)
	local buttonMode

	if mode == "units" then
		mode = L"changeUnits:unitsMode"
		buttonMode = L"changeUnits:keymapMode"
	elseif mode == "keymap" then
		mode = L"changeUnits:keymapMode"
		buttonMode = L"changeUnits:unitsMode"
	else
		error("invalid mode")
	end

	text:clear()
	util.addTextWithShadow(text, L("changeUnits:mode", {mode = mode}), 420, 8)
	button:setText(buttonMode)
end

local function applySetting(_, self)
	local uval, kval = {}, {}

	for i = 9, 1, -1 do
		uval[#uval + 1] = self.persist.unitList[i]
		kval[#kval + 1] = self.persist.keymap[i]
		self.persist.currentUnitList[i] = self.persist.unitList[i]
		self.persist.currentKeymap[i] = self.persist.keymap[i]
	end

	setting.set("IDOL_IMAGE", table.concat(uval, "\t"))
	setting.set("IDOL_KEYS", table.concat(kval, "\t"))
end

local function revertSetting(_, self)
	for i = 1, 9 do
		self.persist.unitList[i] = self.persist.currentUnitList[i]
		self.persist.keymap[i] = self.persist.currentKeymap[i]
	end
end

local function setMode(_, self)
	if self.persist.mode == "units" then
		self.persist.mode = "keymap"
	elseif self.persist.mode == "keymap" then
		self.persist.mode = "units"
	else
		error("invalid mode")
	end

	updateCurrentMode(self.data.modeText, self.data.modeButton, self.persist.mode)
end

local function leave(_, self)
	revertSetting(nil, self)
	return gamestate.leave(loadingInstance.getInstance())
end

function changeUnits:load()
	glow.clear()

	if self.data.mainFont == nil then
		self.data.mainFont = mainFont.get(24)
	end
	local font = self.data.mainFont

	if self.data.changeUnitText == nil then
		self.data.changeUnitText = constructCenteredText(font, 120, L"changeUnits:unitsText")
	end

	if self.data.keymapText == nil then
		self.data.keymapText = constructCenteredText(font, 120, L"changeUnits:keymapText")
	end

	if self.data.applyText == nil then
		self.data.applyText = constructCenteredText(font, 260, L"changeUnits:applyText")
	end

	if self.data.modeText == nil then
		self.data.modeText = love.graphics.newText(font)
	end

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"menu:changeUnits")
		self.data.back:addEventListener("mousereleased", leave)
	end
	self.data.back:setData(self)
	glow.addFixedElement(self.data.back, 0, 0)

	if self.data.applyButton == nil then
		self.data.applyButton = imageButton("assets/image/ui/com_button_14")
		self.data.applyButton:addEventListener("mousereleased", applySetting)
	end
	self.data.applyButton:setData(self)
	glow.addElement(self.data.applyButton, 808, 574)

	if self.data.cancelButton == nil then
		self.data.cancelButton = imageButton("assets/image/ui/com_button_15")
		self.data.cancelButton:addEventListener("mousereleased", revertSetting)
	end
	self.data.cancelButton:setData(self)
	glow.addElement(self.data.cancelButton, 808, 500)

	if self.data.modeButton == nil then
		self.data.modeButton = selectButton("dummy")
		self.data.modeButton:addEventListener("mousereleased", setMode)
	end
	self.data.modeButton:setData(self)
	glow.addElement(self.data.modeButton, 8, 592)

	if self.persist.unitImageList == nil then
		self.persist.unitImageList = setmetatable({}, {
			__index = function()
				return self.assets.images.dummyUnit
			end
		})

		-- scan directory
		local unitLoad = {}
		local unitFilename = {}
		for _, file in ipairs(love.filesystem.getDirectoryItems("unit_icon")) do
			local path = "unit_icon/"..file
			if file:sub(-4) == ".png" and util.fileExists(path) then
				unitLoad[#unitLoad + 1] = {lily.newImage, path, mipmap}
				unitFilename[#unitFilename + 1] = file
			end
		end

		-- load (cannot use assetCache because it caches the image)
		local unitImage = lily.loadMulti(unitLoad)
		async.syncLily(unitImage):sync()
		for i = 1, #unitFilename do
			local image = unitImage:getValues(i)
			local w, h = image:getDimensions()
			if w == 128 and h == 128 then
				self.persist.unitImageList[unitFilename[i]] = unitImage:getValues(i)
			end
		end
	end
end

function changeUnits:start()
	self.persist.currentUnitList = {}
	self.persist.unitList = {}
	self.persist.currentKeymap = {}
	self.persist.keymap = {}
	self.persist.mode = "units"
	self.persist.selectUnits = nil
	updateCurrentMode(self.data.modeText, self.data.modeButton, self.persist.mode)

	-- load unit image name
	do
		local i = 9
		for w in setting.get("IDOL_IMAGE"):gmatch("[^\t]+") do
			self.persist.unitList[i] = w
			self.persist.currentUnitList[i] = w
			i = i - 1
		end

		assert(i == 0, "improper idol image setting")
	end

	-- load keymap
	do
		local i = 9
		for w in setting.get("IDOL_KEYS"):gmatch("[^\t]+") do
			self.persist.keymap[i] = w
			self.persist.currentKeymap[i] = w
			i = i - 1
		end

		assert(i == 0, "improper keymap setting")
	end
end

function changeUnits:resumed()
	if self.persist.selectUnits and self.persist.selectUnits.reference.value then
		self.persist.unitList[self.persist.selectUnits.index] = self.persist.selectUnits.reference.value
	end

	updateCurrentMode(self.data.modeText, self.data.modeButton, self.persist.mode)
end

function changeUnits:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.applyText)
	love.graphics.draw(self.data.modeText)

	for i = 1, 9 do
		love.graphics.draw(
			self.persist.unitImageList[self.persist.unitList[i]],
			idolPosition[i][1], idolPosition[i][2], 0, 1, 1, 64, 64
		)
	end

	-- keymap test
	if not(self.persist.keymapIndex) then
		love.graphics.setColor(color.orangeRed)
		for i = 1, 9 do
			if love.keyboard.isDown(self.persist.keymap[i]) then
				love.graphics.draw(
					self.assets.images.dummyUnit,
					idolPosition[i][1], idolPosition[i][2], 0, 1, 1, 64, 64
				)
			end
		end
		love.graphics.setColor(color.white)
	end

	if self.persist.mode == "units" then
		love.graphics.draw(self.data.changeUnitText)
	elseif self.persist.mode == "keymap" then
		love.graphics.setFont(self.data.mainFont)
		love.graphics.draw(self.data.keymapText)

		-- keymap overlay
		local h = self.data.mainFont:getHeight()
		for i = 1, 9 do
			local key = self.persist.keymapIndex == i and "..." or self.persist.keymap[i]
			local pos = idolPosition[i]
			love.graphics.setColor(color.white75PT)
			love.graphics.rectangle("fill", pos[1] - 64, pos[2] + 40, 128, h)
			love.graphics.setColor(color.black75PT)
			love.graphics.print(key:upper(), pos[1] - self.data.mainFont:getWidth(key) * 0.5, pos[2] + 40)
		end
	else
		error("invalid mode")
	end

	glow.draw()
end

changeUnits:registerEvent("mousereleased", function(self, x, y)
	for i = 1, 9 do
		if util.distance(x, y, idolPosition[i][1], idolPosition[i][2]) <= 64 then
			if self.persist.mode == "units" then
				local ref = {}
				self.persist.selectUnits = {
					index = i,
					reference = ref
				}
				gamestate.enter(nil, "selectUnits", {self.persist.unitImageList, ref})
			elseif self.persist.mode == "keymap" then
				self.persist.keymapIndex = i
			end

			return
		end
	end
end)

local unmapableKeys = {
	-- Navigation Keys
	"up", "down", "left", "right",
	"home", "end",
	"pageup", "pagedown",
	-- Editing Keys
	"insert",
	"backspace",
	"tab",
	"clear",
	"return",
	"delete",
	-- Function Keys (some used specially by game)
	"f1", "f2", "f3", "f4",
	"f5", "f6", "f7", "f8",
	"f9", "f10", "f11", "f12",
	"f13", "f14", "f15", "f16",
	-- Modifier keys
	"numlock",
	"capslock",
	"scrolllock",
	"rshift", "lshift",
	"rctrl", "lctrl",
	"ralt", "lalt",
	"rgui", "lgui",
	"mode",
	-- Application Keys
	"www",
	"mail",
	"calculator",
	"computer",
	"appsearch",
	"apphome",
	"appback",
	"appforward",
	"apprefresh",
	"appbookmarks",
	-- Misc. Keys
	"pause",
	"escape",
	"help",
	"printscreen",
	"sysreq",
	"menu",
	"application",
	"power",
	"currencyunit",
	"undo",
}

changeUnits:registerEvent("keyreleased", function(self, key)
	if self.persist.keymapIndex then
		-- unmappable keys means "cancel"
		for i = 1, #unmapableKeys do
			if unmapableKeys[i] == key then
				self.persist.keymapIndex = nil
				return
			end
		end

		-- Key is mappable
		local kmap = self.persist.keymap
		-- check if it's same key
		if kmap[self.persist.keymapIndex] == key then
			-- cancel
			self.persist.keymapIndex = nil
			return
		end

		-- Check if this key is already used by different unit
		for i = 1, 9 do
			if kmap[i] == key then
				-- swap keys
				kmap[i], kmap[self.persist.keymapIndex] = kmap[self.persist.keymapIndex], kmap[i]
				self.persist.keymapIndex = nil
				return
			end
		end

		-- It's not used anywhere. Assign.
		kmap[self.persist.keymapIndex] = key
		self.persist.keymapIndex = nil
	elseif key == "escape" then
		return leave(nil, self)
	end
end)

return changeUnits
