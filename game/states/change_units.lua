-- Change Units
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local timer = require("libs.hump.timer")
local CubicBezier = require("libs.cubic_bezier")

local Async = require("async")
local color = require("color")
local MainFont = require("main_font")
local lily = require("lily")
local Setting = require("setting")
local Util = require("util")
local L = require("language")

local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")

local BackgroundLoader = require("game.background_loader")
local ColorTheme = require("game.color_theme")

local Glow = require("game.afterglow")
local CircleIconButton = require("game.ui.circle_icon_button")
local StripeText = require("game.ui.stripe_text")

local mipmap = {mipmaps = true}
local materialInterpolation = CubicBezier(0.4, 0.0, 0.2, 1):getFunction()

local changeUnits = Gamestate.create {
	images = {
		dummyUnit = {"assets/image/dummy.png", mipmap},
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmap},
		keyboard = {"assets/image/ui/over_the_rainbow/keyboard.png", mipmap},
		save = {"assets/image/ui/over_the_rainbow/save.png", mipmap},
		revert = {"assets/image/ui/over_the_rainbow/revert.png", mipmap},
		unit = {"assets/image/ui/over_the_rainbow/perm_identity_24px.png", mipmap}
	},
	fonts = {},
}

local idolPosition = {
	{816, 96 },
	{785, 249},
	{698, 378},
	{569, 465},
	{416, 496},
	{262, 465},
	{133, 378},
	{46 , 249},
	{16 , 96 },
}

local RECT_BLUR_OVERLAY = {250, 121, 460, 256}

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

local function showUnitList(self)
	for i = 1, 9 do
		local x = idolPosition[i]
		Glow.addElement(self.data.dummyButtons[i], x[1], x[2])
	end
end

local function hideUnitList(self)
	for i = 1, 9 do
		Glow.removeElement(self.data.dummyButtons[i])
	end
end

local function showSaveRevertButton(self)
	Glow.addFixedElement(self.data.saveButton, 731, 524)
	Glow.addFixedElement(self.data.revertButton, 827, 524)
	Glow.addFixedElement(self.data.modeButton, 700, 4)
end

local function hideSaveRevertButton(self)
	Glow.removeElement(self.data.saveButton)
	Glow.removeElement(self.data.revertButton)
	Glow.removeElement(self.data.modeButton)
end

local function applySetting(_, self)
	local uval, kval = {}, {}

	for i = 9, 1, -1 do
		uval[#uval + 1] = self.persist.unitList[i]
		kval[#kval + 1] = self.persist.keymap[i]
		self.persist.currentUnitList[i] = self.persist.unitList[i]
		self.persist.currentKeymap[i] = self.persist.keymap[i]
	end

	Setting.set("IDOL_IMAGE", table.concat(uval, "\t"))
	Setting.set("IDOL_KEYS", table.concat(kval, "\t"))
end

local function revertSetting(_, self)
	for i = 1, 9 do
		local unit = self.persist.currentUnitList[i]
		self.persist.unitList[i] = unit
		self.persist.keymap[i] = self.persist.currentKeymap[i]
		self.data.dummyButtons[i]:setImage(self.persist.unitImageList[unit])
	end
end

local function constructCenteredText(font, text)
	local t = love.graphics.newText(font)
	local h = font:getHeight()

	-- Text has horizontal padding of 32
	local textarea = RECT_BLUR_OVERLAY[3] - 64
	local wrap = select(2, font:getWrap(text, textarea))

	t:addf(
		text, textarea, "center",
		32 + RECT_BLUR_OVERLAY[1],
		(RECT_BLUR_OVERLAY[4] - #wrap * h) * 0.5 + RECT_BLUR_OVERLAY[2]
	)
	return t
end

local function updateCurrentMode(text, button, img, mode)
	if mode == "units" then
		mode = L"changeUnits:unitsMode"
	elseif mode == "keymap" then
		mode = L"changeUnits:keymapMode"
	else
		error("invalid mode")
	end

	text:clear()
	text:add(mode)
	button:setImage(img, 0.48)
end

local function setMode(_, self)
	local mimg

	if self.persist.mode == "units" then
		self.persist.mode = "keymap"
		mimg = self.assets.images.unit

		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOpacity = 1}, materialInterpolation)
	elseif self.persist.mode == "keymap" then
		self.persist.mode = "units"
		mimg = self.assets.images.keyboard

		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOpacity = 0}, materialInterpolation)
	else
		error("invalid mode")
	end

	updateCurrentMode(self.data.modeText, self.data.modeButton, mimg, self.persist.mode)
end

local function tryLeave(_, self)
	if self.persist.selectUnits > 0 then
		self.persist.selectUnits = -1
		self.persist.startUnitSelector = false
		showSaveRevertButton(self)
	elseif self.persist.keymapIndex > 0 then
		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOverlayOpacity = 0}, materialInterpolation)
		self.persist.timer:after(0.2, function()
			showUnitList(self)
			showSaveRevertButton(self)
		end)
		self.persist.keymapIndex = -1
	else
		-- Check settings
		local isChanged = false

		for i = 1, 9 do
			if
				self.persist.keymap[i] ~= self.persist.currentKeymap[i] or
				self.persist.unitList[i] ~= self.persist.currentUnitList[i]
			then
				isChanged = true
				break
			end
		end

		if isChanged then
			local buttons = {
				L"dialog:no",
				L"dialog:yes",
				L"dialog:cancel",
				enterbutton = 2,
				exitbutton = 1
			}
			local r = love.window.showMessageBox(L"menu:changeUnits", L"changeUnits:exitConfirm", buttons, "warning")

			if r == 2 then
				applySetting(nil, self)
			elseif r == 3 then
				-- don't let it enter gamestate.leave
				return
			end
		end

		Gamestate.leave(LoadingInstance.getInstance())
	end
end

local function stencilTextPlacement()
	return love.graphics.rectangle(
		"fill",
		RECT_BLUR_OVERLAY[1],
		RECT_BLUR_OVERLAY[2],
		RECT_BLUR_OVERLAY[3],
		RECT_BLUR_OVERLAY[4]
	)
end

local function changeUnit(_, data)
	local self = data[1]
	local index = data[2]

	if self.persist.selectUnits > 0 or self.persist.keymapIndex > 0 then
		return
	end

	if self.persist.mode == "units" then
		self.persist.selectUnits = index
		self.persist.startUnitSelector = true
		hideSaveRevertButton(self)
	elseif self.persist.mode == "keymap" then
		self.persist.keymapIndex = index

		self.persist.timer:clear()
		self.persist.timer:tween(0.2, self.persist, {keymapOverlayOpacity = 1}, materialInterpolation)
		hideUnitList(self)
		hideSaveRevertButton(self)
	end
end

local function selectedNewUnit(_, data)
	local self = data[1]

	if self.persist.selectUnits > 0 then
		local val = data[2].items[data[3]]
		showUnitList(self)
		showSaveRevertButton(self)
		self.persist.unitList[self.persist.selectUnits] = val[2]
		self.data.dummyButtons[self.persist.selectUnits]:setImage(val[3])
		self.persist.selectUnits = -1
		self.persist.startUnitSelector = false
	end
end

local function isImageFitInUnitIconCriteria(path)
	-- File not exist? ignore
	if not(Util.fileExists(path)) then return false end

	-- Other issue should be reported to user immediately!
	local f = assert(Util.newFileCompat(path, "r"))

	-- Not PNG? ignore
	if f:read(16) ~= "\137PNG\r\n\26\n\0\0\0\13IHDR" then
		f:close()
		return false
	end

	local dimensions = f:read(8)

	f:close()

	local a, b, c, d = dimensions:byte(1, 4)
	local width = d + c * 256 + b * 65536 + a * 16777216
	a, b, c, d = dimensions:byte(5, 8)
	local height = d + c * 256 + b * 65536 + a * 16777216

	-- not 128x128? it should be false
	return width == 128 and height == 128
end

function changeUnits:load()
	local centeredInfoFont
	Glow.clear()

	local function loadCenteredInfoFont()
		if not(centeredInfoFont) then
			centeredInfoFont = MainFont.get(18)
		end
	end

	if self.data.textShader == nil then
		self.data.textShader = love.graphics.newShader([[
			vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
			{
				return color * vec4(1.0, 1.0, 1.0, Texel(tex, tc).a);
			}
		]])
	end

	if self.data.titleText == nil then
		local f = MainFont.get(31)
		local t = love.graphics.newText(f)
		local l = L"menu:changeUnits"
		t:add(l, -0.5 * f:getWidth(l), 0)
		self.data.titleText = t
	end

	if self.data.keymapTitleText == nil then
		local f = MainFont.get(31)
		local t = love.graphics.newText(f)
		local l = L"changeUnits:keymapTitle"
		t:add(l, -0.5 * f:getWidth(l), 0)
		self.data.keymapTitleText = t
	end

	if self.data.keymapFont == nil then
		self.data.keymapFont = MainFont.get(18)
	end

	if self.data.changeUnitText == nil then
		loadCenteredInfoFont()
		self.data.changeUnitText = constructCenteredText(centeredInfoFont, L"changeUnits:unitsDesc")
	end

	if self.data.selectUnitsText == nil then
		self.data.selectUnitsText = love.graphics.newText(MainFont.get(31))
		self.data.selectUnitsText:add({ColorTheme.get(), L"changeUnits:selectUnits"})
	end

	if self.data.keymapText == nil then
		loadCenteredInfoFont()
		self.data.keymapText = constructCenteredText(centeredInfoFont, L"changeUnits:keymapDesc")
	end

	if self.data.keymapSelectText == nil then
		loadCenteredInfoFont()
		self.data.keymapSelectText = constructCenteredText(centeredInfoFont, L"changeUnits:keymapSelectDesc")
	end

	if self.data.modeText == nil then
		loadCenteredInfoFont()
		self.data.modeText = love.graphics.newText(centeredInfoFont)
	end

	if self.data.modeButton == nil then
		self.data.modeButton = CircleIconButton(ColorTheme.get(), 36)
		self.data.modeButton:addEventListener("mousereleased", setMode)
		self.data.modeButton:setData(self)
	end
	Glow.addFixedElement(self.data.modeButton, 700, 4)

	if self.data.saveButton == nil then
		self.data.saveButton = CircleIconButton(color.hexFF4FAE, 45, self.assets.images.save, 0.32)
		self.data.saveButton:setShadow(32, math.pi, 6)
		self.data.saveButton:addEventListener("mousereleased", applySetting)
		self.data.saveButton:setData(self)
	end
	Glow.addFixedElement(self.data.saveButton, 731, 524)

	if self.data.revertButton == nil then
		self.data.revertButton = CircleIconButton(color.hexFF6854, 45, self.assets.images.revert, 0.32)
		self.data.revertButton:setShadow(32, math.pi, 6)
		self.data.revertButton:addEventListener("mousereleased", revertSetting)
		self.data.revertButton:setData(self)
	end
	Glow.addFixedElement(self.data.revertButton, 827, 524)

	if self.data.background == nil then
		self.data.background = BackgroundLoader.load(5)
	end

	-- Setup unit formation
	if self.data.dummyButtons == nil then
		local dummy = self.assets.images.dummyUnit
		self.data.dummyButtons = {
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy),
			CircleIconButton(color.transparent, 64, dummy)
		}
	end
	for i = 1, 9 do
		local x = idolPosition[i]
		self.data.dummyButtons[i]:setData({self, i})
		self.data.dummyButtons[i]:addEventListener("mousereleased", changeUnit)
		Glow.addElement(self.data.dummyButtons[i], x[1], x[2])
	end

	-- Nice effect but I usually used this sparingly
	if self.data.blurFramebuffer == nil then
		self.data.blurFramebuffer = Util.drawBlur(480, 320, 1.5, function()
			love.graphics.setColor(color.white)
			love.graphics.draw(self.data.background, 0, 0, 0, 0.5, 0.5)
		end)
	end

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = Util.gradient("vertical", color.black75PT, color.transparent)
	end

	if self.data.back == nil then
		self.data.back = CircleIconButton(ColorTheme.get(), 36, self.assets.images.navigateBack, 0.48)
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", tryLeave)
	end
	Glow.addFixedElement(self.data.back, 32, 4)

	-- Units loading
	if self.persist.unitImageList == nil then
		local unitImageList = setmetatable({}, {
			__index = function()
				return self.assets.images.dummyUnit
			end
		})

		-- scan directory
		local unitLoad = {}
		local unitFilename = {}
		for _, file in ipairs(love.filesystem.getDirectoryItems("unit_icon")) do
			local path = "unit_icon/"..file

			if Util.directoryExist(path) then
				-- Scan at 1 folder deep. The code below is bit repetitive.
				for _, file2 in ipairs(love.filesystem.getDirectoryItems(path)) do
					local path2 = path.."/"..file2

					if isImageFitInUnitIconCriteria(path2) then
						unitLoad[#unitLoad + 1] = {lily.newImage, path2, mipmap}
						unitFilename[#unitFilename + 1] = file.."/"..file2
					end
				end
			elseif isImageFitInUnitIconCriteria(path) then
				unitLoad[#unitLoad + 1] = {lily.newImage, path, mipmap}
				unitFilename[#unitFilename + 1] = file
			end
		end

		-- load (cannot use assetCache because it caches the image)
		local unitImage = lily.loadMulti(unitLoad)
		Async.syncLily(unitImage):sync()

		for i = 1, #unitFilename do
			local img = unitImage:getValues(i)
			unitImageList[unitFilename[i]] = img
			unitImageList[#unitImageList + 1] = {i, unitFilename[i], img}
		end

		self.persist.unitImageList = unitImageList
	end
end

function changeUnits:start()
	self.persist.currentUnitList = {}
	self.persist.unitList = {}
	self.persist.currentKeymap = {}
	self.persist.keymap = {}
	self.persist.keymapIndex = -1
	self.persist.mode = "units"
	self.persist.selectUnits = -1
	self.persist.timer = timer.new()
	self.persist.keymapOpacity = 0
	self.persist.keymapOverlayOpacity = 0
	self.persist.keymapHighlightTime = 0
	self.persist.unitSelectorTime = 0
	self.persist.unitSelectorLerp = 0
	self.persist.startUnitSelector = false

	updateCurrentMode(self.data.modeText, self.data.modeButton, self.assets.images.keyboard, self.persist.mode)

	-- load unit image name
	do
		local i = 9
		for w in Setting.get("IDOL_IMAGE"):gmatch("[^\t]+") do
			self.persist.unitList[i] = w
			self.persist.currentUnitList[i] = w
			self.data.dummyButtons[i]:setImage(self.persist.unitImageList[w])
			i = i - 1
		end

		assert(i == 0, "improper idol image setting")
	end

	-- load keymap
	do
		local i = 9
		for w in Setting.get("IDOL_KEYS"):gmatch("[^\t]+") do
			self.persist.keymap[i] = w
			self.persist.currentKeymap[i] = w
			i = i - 1
		end

		assert(i == 0, "improper keymap setting")
	end

	-- Categorize unit icons by directory
	local unitSelectCategory = {{name = "", y = 0, items = {}}}

	for _, info in ipairs(self.persist.unitImageList) do
		local path = info[2]
		local pathsep = path:find("/", 1, true)
		local cat

		if pathsep then
			-- Put in other category
			local categoryName = path:sub(1, pathsep - 1)

			for _, v in Util.ipairsi(unitSelectCategory, 2) do
				if v.name == categoryName then
					cat = v
					break
				end
			end

			if cat == nil then
				cat = {name = categoryName, y = 0, items = {}}
				unitSelectCategory[#unitSelectCategory + 1] = cat
			end
		else
			cat = unitSelectCategory[1]
		end

		cat.items[#cat.items + 1] = info
	end

	-- load unit select frame
	local frame = Glow.Frame(77, 266, 856, 372)
	self.persist.unitSelectPosition = {}
	self.persist.unitSelectFrame = frame

	local ytrack = 0
	for i, v in ipairs(unitSelectCategory) do
		if v.name ~= "" then
			local sep = StripeText(self.data.keymapFont, v.name, 4, 819)
			frame:addElement(sep, 0, ytrack)
			ytrack = ytrack + 8 + select(2, sep:getDimensions())
			v.y = ytrack
		end

		for k, v2 in ipairs(v.items) do
			local x = (k - 1) % 7
			local y = math.floor((k - 1) / 7)
			local button = CircleIconButton(color.transparent, 54, v2[3], 108/128)
			button:setData({self, v, k})
			button:addEventListener("mousereleased", selectedNewUnit)
			frame:addElement(button, x * 117, y * 117 + ytrack)
		end

		ytrack = ytrack + 8 + math.ceil(#v.items / 7) * 117
	end
end

function changeUnits:update(dt)
	self.persist.timer:update(dt)
	self.persist.unitSelectFrame:update(dt)

	if self.persist.keymapIndex > 0 then
		self.persist.keymapHighlightTime = (self.persist.keymapHighlightTime + dt) % 2
	end

	local prev = self.persist.unitSelectorTime
	if self.persist.startUnitSelector then
		self.persist.unitSelectorTime = math.min(self.persist.unitSelectorTime + dt * 2, 1)

		if self.persist.unitSelectorTime ~= prev and self.persist.unitSelectorTime > 0 then
			Glow.addFrame(self.persist.unitSelectFrame)
		end
	else
		self.persist.unitSelectorTime = math.max(self.persist.unitSelectorTime - dt * 2, 0)

		if self.persist.unitSelectorTime ~= prev and self.persist.unitSelectorTime == 0 then
			Glow.removeFrame(self.persist.unitSelectFrame)
		end
	end

	self.persist.unitSelectorLerp = 640 - materialInterpolation(self.persist.unitSelectorTime) * 499
	self.persist.unitSelectFrame:setPosition(77, self.persist.unitSelectorLerp + 127)
end

function changeUnits:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(ColorTheme.get())
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(color.white)
	love.graphics.setShader(self.data.textShader)
	if self.persist.mode == "units" then
		love.graphics.draw(self.data.titleText, 480, 24)
	elseif self.persist.mode == "keymap" then
		love.graphics.draw(self.data.keymapTitleText, 480, 24)
	end
	love.graphics.setShader()
	Glow.draw()

	love.graphics.setColor(color.white)

	if self.persist.keymapIndex <= 0 then
		love.graphics.draw(self.data.modeText, 780, 32)
	end

	if self.persist.keymapOpacity > 0 then
		if self.persist.keymapOverlayOpacity > 0 then
			-- Draw dummy units
			love.graphics.setColor(color.white)
			for i = 1, 9 do
				if i ~= self.persist.keymapIndex then
					local x = idolPosition[i]
					love.graphics.draw(self.persist.unitImageList[self.persist.unitList[i]], x[1], x[2])
				end
			end
		end

		-- Show key overlay
		love.graphics.setColor(color.compat(60, 57, 57, self.persist.keymapOpacity))

		for i = 1, 9 do
			if i ~= self.persist.keymapIndex then
				local x = idolPosition[i]
				love.graphics.rectangle("fill", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
				love.graphics.rectangle("line", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
			end
		end

		-- Show key text
		-- It's better to use love.graphics.printf(text, Font) variant here
		-- but that variant is only supported in 11.0 and later
		love.graphics.setFont(self.data.keymapFont)
		love.graphics.setColor(color.compat(255, 255, 255, self.persist.keymapOpacity))
		local h = self.data.keymapFont:getHeight() * 0.5
		for i = 1, 9 do
			if i ~= self.persist.keymapIndex then
				local x = idolPosition[i]
				local key = self.persist.keymap[i]
				love.graphics.printf(key:upper(), x[1] - 5, x[2] + 104 - h, 138, "center")
			end
		end

		if self.persist.keymapIndex > 0 then
			-- Draw gray rectangle
			love.graphics.setColor(color.compat(70, 69, 69, self.persist.keymapOverlayOpacity * 0.65))
			love.graphics.rectangle("fill", -88, -43, 1136, 726)

			-- Highlight the current selected unit
			local i = self.persist.keymapIndex
			local x = idolPosition[i]

			love.graphics.setColor(color.white)
			love.graphics.draw(self.persist.unitImageList[self.persist.unitList[i]], x[1], x[2])
			love.graphics.setColor(color.compat(60, 57, 57, self.persist.keymapOpacity))
			love.graphics.rectangle("fill", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
			love.graphics.rectangle("line", x[1] - 5, x[2] + 88, 138, 32, 14, 14)
			love.graphics.setColor(color.compat(255, 255, 255, math.abs(1 - self.persist.keymapHighlightTime)))
			love.graphics.printf("PRESS KEY", x[1] - 5, x[2] + 104 - h, 138, "center")
		end
	end

	if self.persist.keymapOverlayOpacity < 1 then
		love.graphics.setColor(color.white)
		Util.stencil11(stencilTextPlacement, "replace", 2, true)
		Util.setStencilTest11("equal", 2)
		love.graphics.draw(self.data.blurFramebuffer, 0, 0, 0, 2, 2)
		love.graphics.setColor(color.compat(53, 53, 53, 0.5 + self.persist.keymapOverlayOpacity * 0.5))
		Util.setStencilTest11()
		stencilTextPlacement()
	else
		love.graphics.setColor(color.hex353535)
		stencilTextPlacement()
	end

	love.graphics.setColor(color.white)
	if self.persist.keymapIndex > 0 then
		love.graphics.draw(self.data.keymapSelectText)
	elseif self.persist.mode == "keymap" then
		love.graphics.draw(self.data.keymapText)
	else
		love.graphics.draw(self.data.changeUnitText)
	end

	if self.persist.unitSelectorTime > 0 then
		love.graphics.setColor(color.white)
		love.graphics.rectangle("fill", 26, self.persist.unitSelectorLerp, 908, 498)
		love.graphics.draw(self.data.selectUnitsText, 78, self.persist.unitSelectorLerp + 36)
		self.persist.unitSelectFrame:draw()
	end
end

changeUnits:registerEvent("keyreleased", function(self, _, scancode)
	if scancode == "escape" then
		tryLeave(nil, self)
	elseif self.persist.keymapIndex > 0 then
		-- unmappable keys means "cancel"
		for i = 1, #unmapableKeys do
			if unmapableKeys[i] == scancode then
				tryLeave(nil, self)
				return
			end
		end

		-- Key is mappable
		local kmap = self.persist.keymap
		-- check if it's same key
		if kmap[self.persist.keymapIndex] == scancode then
			-- cancel
			tryLeave(nil, self)
			return
		end

		-- Check if this key is already used by different unit
		for i = 1, 9 do
			if kmap[i] == scancode then
				-- swap keys
				kmap[i], kmap[self.persist.keymapIndex] = kmap[self.persist.keymapIndex], kmap[i]
				tryLeave(nil, self)
				return
			end
		end

		-- It's not used anywhere. Assign.
		kmap[self.persist.keymapIndex] = scancode
		tryLeave(nil, self)
	end
end)

return changeUnits
