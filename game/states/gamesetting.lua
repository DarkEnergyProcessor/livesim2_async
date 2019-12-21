-- Game settings
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION

local love = require("love")
local Luaoop = require("libs.Luaoop")

local async = require("async")
local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local mainFont = require("font")
local util = require("util")
local volume = require("volume")
local setting = require("setting")
local L = require("language")

local backgroundLoader = require("game.background_loader")
local tapSound = require("game.tap_sound")
local colorTheme = require("game.color_theme")

local glow = require("game.afterglow")
local ciButton = require("game.ui.circle_icon_button")
local ripple = require("game.ui.ripple")
local invisibleUI = require("game.ui.invisible")

local numberSetting = require("game.settings.number")
local switchSetting = require("game.settings.switch")

local note = require("game.live.note")
local liveUI = require("game.live.ui")
local systemInfo = require("game.systeminfo")

local interpolation = require("libs.cubic_bezier")(0.4, 0, 0.2, 1):getFunction()
local mipmap = {mipmaps = true}
local --[[const]] MAX_NOTE_STYLE = 4

local aboutString = string.format([[
Live Simulator: 2 Version %s

Live Simulator: 2 v3.0 and later is licensed under zLib license.
Copyright (c) 2040 Dark Energy Processor
This software is provided 'as-is', without any express or implied warranty. In no event will the authors be held liable for any damages arising from the use of this software.
Permission is granted to anyone to use this software for any purpose, including commercial applications, and to alter it and redistribute it freely, subject to the following restrictions:
1. The origin of this software must not be misrepresented; you must not claim that you wrote the original software. If you use this software in a product, an acknowledgment in the product documentation would be appreciated but is not required.
2. Altered source versions must be plainly marked as such, and must not be misrepresented as being the original software.
3. This notice may not be removed or altered from any source distribution.

Special thanks to:
* yuyu - Note circle images and Japanese translation.
* MilesElectric168 - Note randomization algorithm.
* sr229 - v4.0 UI redesign.
* CK.Tex - Simplified Chinese translation.
* Bass & Azux - Polish translation.
* Luboss - Slovak translation.
* RayFirefist - macOS app, iOS maintainer, Italian translation.
* jwun & TheNozomi - Spanish translation.
* Salaron & Nick "Zorb" Cage - Russian translation.
]], DEPLS_VERSION):gsub("\r\n", "\n")

local function leave(_, self)
	local ct = assert(tonumber(setting.get("COLOR_THEME")))
	if
		util.compareLOVEVersion(0, 10, 2) >= 0 and
		(
			self.persist.currentLanguage ~= self.persist.previousLanguage or
			self.persist.currentTheme ~= ct
		) and
		love.window.showMessageBox("Restart", L"dialog:restart", {
			L"dialog:yes",
			L"dialog:no",
			enterbutton = 1, escapebutton = 2
		}, "info") == 1
	then
		love.event.quit("restart")
	end

	return gamestate.leave(loadingInstance.getInstance())
end

local function setVolumeSetting(name, value)
	return volume.set(name, value * 0.01)
end

local function changeBackgroundAsync(self, v)
	self.persist.background = backgroundLoader.load(v)
end

local function startChangeBackground(self, v)
	return async.runFunction(changeBackgroundAsync):run(self, v)
end

local function setBackgroundDim(self, v)
	self.persist.backgroundDim = v / 100
end

local function updateStyleData(self)
	self.persist.styleLayer[1] = note.manager.getLayer(self.persist.styleData, 1, true, true, false, false)
	self.persist.styleLayer[2] = note.manager.getLayer(self.persist.styleData, 2, true, true, false, false)
	self.persist.styleLayer[3] = note.manager.getLayer(self.persist.styleData, 3, true, true, false, false)
	self.persist.curStyle = note.manager.getLayer(self.persist.styleData, self.persist.defAttr, true, true, false, false)

	-- simultaneous neon doesn't provide base frame if base frame is also neon
	if self.persist.styleData.noteStyleFrame == 2 then
		self.persist.curStyle[#self.persist.curStyle + 1] = self.persist.defAttr + 16
	end

	-- calculate note style value
	setting.set("NOTE_STYLE", 63 +
		self.persist.styleData.noteStyleFrame * 64 +
		self.persist.styleData.noteStyleSwing * 4096 +
		self.persist.styleData.noteStyleSimul * 262144
	)
end

local function isSimultaneousLayer(layerIndex)
	return layerIndex == 16 or layerIndex == 28 or layerIndex == 62 or layerIndex == 86
end

local tempPosition = {x = 0, y = 0}
local function drawLayerAt(styleData, layer, x, y)
	tempPosition.x, tempPosition.y = x, y
	return note.manager.drawNote(styleData, layer, 1, tempPosition, 0.75, 0)
end

local function newSettingFrame()
	return glow.frame(246, 86, 714, 548)
end

local categorySelect = Luaoop.class("Livesim2.Settings.CategorySelectUI", glow.element)

function categorySelect:new(font, icon, name)
	self.width, self.height = 240, 48
	self.x, self.y = 0, 0
	self.active = false
	self.ripple = ripple(242.12393520674489483506979278946)
	self.isPressed = false
	self.textHeight = font:getHeight()
	self.text = love.graphics.newText(font)
	self.text:add(assert(name), 0, (self.height - font:getHeight()) * 0.5)
	self.icon = assert(icon)
	self.iconW, self.iconH = icon:getDimensions()
	self.stencilFunc = function()
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", categorySelect._pressed)
	self:addEventListener("mousereleased", categorySelect._released)
	self:addEventListener("mousecanceled", categorySelect._released)
end

function categorySelect:_pressed(_, x, y)
	self.isPressed = true
	self.ripple:pressed(x, y)
end

function categorySelect:_released()
	self.isPressed = false
	self.ripple:released()
end

function categorySelect:setActive(active)
	self.active = active
end

function categorySelect:update(dt)
	self.ripple:update(dt)
end

function categorySelect:render(x, y)
	self.x, self.y = x, y
	if self.active then
		love.graphics.setColor(colorTheme.get())
		love.graphics.rectangle("fill", x, y, self.width, self.height)
	end
	love.graphics.setColor(self.active and color.white or color.black)
	love.graphics.draw(self.icon, x + 24, y + 24, 0, 0.32, 0.32, self.iconW * 0.5, self.iconH * 0.5)
	util.drawText(self.text, x + 48, y)

	if self.ripple:isActive() then
		love.graphics.stencil(self.stencilFunc, "replace", 3, false)
		love.graphics.setStencilTest("equal", 3)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
	end
end

local longSelect = Luaoop.class("Livesim2.Settings.LongSelectUI", glow.element)

function longSelect:new(font, name)
	self.width, self.height = 710, 60
	self.x, self.y = 0, 0
	self.active = false
	self.ripple = ripple(712.53070109294238045145069048472)
	self.isPressed = false
	self.textHeight = font:getHeight()
	self.text = love.graphics.newText(font)
	self.text:add(name, (self.width - font:getWidth(name)) * 0.5, (self.height - font:getHeight()) * 0.5)
	self.stencilFunc = function()
		love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
	end

	self:addEventListener("mousepressed", categorySelect._pressed)
	self:addEventListener("mousereleased", categorySelect._released)
	self:addEventListener("mousecanceled", categorySelect._released)
end

function longSelect:setActive(active)
	self.active = active
end

function longSelect:update(dt)
	self.ripple:update(dt)
end

function longSelect:render(x, y)
	self.x, self.y = x, y
	love.graphics.setColor(self.active and colorTheme.get() or color.white75PT)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.setColor(self.active and color.white or color.black)
	util.drawText(self.text, x, y)

	if self.ripple:isActive() then
		love.graphics.stencil(self.stencilFunc, "replace", 3, false)
		love.graphics.setStencilTest("equal", 3)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
	end
end

local textUI = Luaoop.class("Livesim2.TextUI", invisibleUI)

function textUI:new(font, text, maxw)
	self.text = love.graphics.newText(font)
	self.text:addf({color.black, text}, maxw, "left")
	invisibleUI.new(self, maxw, self.text:getHeight())
end

function textUI:render(x, y)
	love.graphics.setColor(color.white)
	util.drawText(self.text, x, y)
end

-- Setting section frame size is 868x426+50+184
-- Tab selection is 868x62+50+162
local gameSetting = gamestate.create {
	images = {
		aspectRatio = {"assets/image/ui/over_the_rainbow/aspect_ratio.png"},
		contacts = {"assets/image/ui/over_the_rainbow/contacts.png"},
		devInfo = {"assets/image/ui/over_the_rainbow/perm_device_information.png", mipmap},
		info = {"assets/image/ui/over_the_rainbow/info.png"},
		language = {"assets/image/ui/over_the_rainbow/language.png"},
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmap},
		note = {"noteImage:assets/image/tap_circle/notes.png", mipmap},
		panorama = {"assets/image/ui/over_the_rainbow/panorama.png"},
		settings = {"assets/image/ui/over_the_rainbow/settings.png"},
		slowMotion = {"assets/image/ui/over_the_rainbow/slow_motion_video.png"},
		volume = {"assets/image/ui/over_the_rainbow/volume_up.png"},
		whatsHot = {"assets/image/ui/over_the_rainbow/whatshot.png"}
	},
	fonts = {}
}

function gameSetting:load()
	glow.clear()
	self.data = self.data or {} -- for sake of LCA
	local font31, font26, font22, font16 = mainFont.get(31, 26, 22, 16)

	if self.persist.background == nil then
		self.persist.background = backgroundLoader.load(tonumber(setting.get("BACKGROUND_IMAGE")))
	end

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = util.gradient("vertical", color.black75PT, color.transparent)
	end

	if self.data.titleText == nil then
		local t = love.graphics.newText(font31)
		local l = L"menu:settings"
		t:add(l, -0.5 * font31:getWidth(l), 0)
		self.data.titleText = t
	end

	if self.data.back == nil then
		self.data.back = ciButton(colorTheme.get(), 36, self.assets.images.navigateBack, 0.48)
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 32, 4)

	-- General settings
	if self.persist.generalSetting == nil then
		local frame = newSettingFrame()
		local themeDisplay = {"μ's", "Aqours", "NijiGaku"}
		local tapSoundDisplay = {}
		for i = 1, #tapSound do
			tapSoundDisplay[i] = tapSound[i].name
		end
		self.persist.generalFrame = frame
		self.persist.generalSetting = {
			numberSetting(frame, L"setting:general:defaultNote", "LLP_SIFT_DEFATTR", {
				min = 1, max = 11,
				display = {
					"Smile", "Pure", "Cool",
					"Blue", "Yellow", "Orange",
					"Pink", "Purple", "Gray",
					"Rainbow", "Black"
				}
			})
				:setPosition(0, 12) -- next: y+=64
				:setChangedCallback(self, function(obj, v)
					obj.persist.defAttr = v
					updateStyleData(obj)
				end),
			switchSetting(frame, L"setting:general:nsAccumulation", "NS_ACCUMULATION")
				:setPosition(0, 64+12),
			numberSetting(frame, L"setting:general:timingOffset", "TIMING_OFFSET", {
				min = -50, max = 50, default = 0
			})
				:setPosition(0, 128+12),
			numberSetting(frame, L"setting:general:beatmapOffset", "GLOBAL_OFFSET", {
				min = -5000, max = 5000, default = 0
			})
				:setPosition(0, 192+12),
			numberSetting(frame, L"setting:general:tapSound", "TAP_SOUND", {
				min = 1, max = #tapSound, default = 1, display = tapSoundDisplay
			})
				:setPosition(0, 256+12),
			switchSetting(frame, L"setting:general:improvedSync", "IMPROVED_SYNC")
				:setPosition(0, 320+12),
			numberSetting(frame, L"setting:general:themeColor", "COLOR_THEME", {
				min = 1, max = 3, default = 1, display = themeDisplay
			})
				:setPosition(0, 384+12)
		}
	end
	glow.addFrame(self.persist.generalFrame)

	-- Volume settings
	if self.persist.volumeSetting == nil then
		local frame = newSettingFrame()
		self.persist.volumeFrame = frame
		self.persist.volumeSetting = {
			numberSetting(frame, L"setting:volume:master", "MASTER_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 12)
				:setChangedCallback("master", setVolumeSetting),
			numberSetting(frame, L"setting:volume:song", "SONG_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 64+12)
				:setChangedCallback("music", setVolumeSetting),
			numberSetting(frame, L"setting:volume:effect", "SE_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 128+12)
				:setChangedCallback("se", setVolumeSetting),
			numberSetting(frame, L"setting:volume:voice", "VOICE_VOLUME", {min = 0, max = 100, default = 80})
				:setPosition(0, 192+12)
				:setChangedCallback("voice", setVolumeSetting),
		}
	end

	-- Background settings
	if self.persist.bgSetting == nil then
		local frame = newSettingFrame()
		self.persist.bgFrame = frame
		self.persist.bgSetting = {
			switchSetting(frame, L"setting:background:loadCustom", "AUTO_BACKGROUND")
				:setPosition(0, 12),
			numberSetting(frame, L"setting:background:image", "BACKGROUND_IMAGE", {min = 1, max = 15})
				:setChangedCallback(self, startChangeBackground)
				:setPosition(0, 64+12),
			numberSetting(frame, L"setting:background:dim", "LIVESIM_DIM", {min = 0, max = 100})
				:setChangedCallback(self, setBackgroundDim)
				:setPosition(0, 128+12)
		}
	end

	-- Note Style settings
	if self.persist.nsSetting == nil then
		local frame = newSettingFrame()
		local display = {"Default", "Neon", "Matte", "Lovewing"}
		self.persist.nsFrame = frame
		self.persist.nsSetting = {
			numberSetting(frame, L"setting:noteStyle:base", nil, {min = 1, max = MAX_NOTE_STYLE, value = 1, display = display})
				:setPosition(0, 12)
				:setChangedCallback(self, function(obj, v)
					obj.persist.styleData.noteStyleFrame = v
					return updateStyleData(obj)
				end),
			numberSetting(frame, L"setting:noteStyle:swing", nil, {min = 1, max = MAX_NOTE_STYLE, value = 1, display = display})
				:setPosition(0, 64+12)
				:setChangedCallback(self, function(obj, v)
					obj.persist.styleData.noteStyleSwing = v
					return updateStyleData(obj)
				end),
			numberSetting(frame, L"setting:noteStyle:simul", nil, {min = 1, max = MAX_NOTE_STYLE, value = 1, display = display})
				:setPosition(0, 128+12)
				:setChangedCallback(self, function(obj, v)
					obj.persist.styleData.noteStyleSimul = v
					return updateStyleData(obj)
				end),
		}
	end

	-- Live settings
	if self.persist.liveSetting == nil then
		local frame = newSettingFrame()
		local vanish = {
			[0] = L"setting:live:vanish:none",
			L"setting:live:vanish:hidden",
			L"setting:live:vanish:sudden"
		}
		self.persist.liveFrame = frame
		self.persist.liveSetting = {
			switchSetting(frame, L"setting:live:customUnits", "CBF_UNIT_LOAD")
				:setPosition(0, 12),
			switchSetting(frame, L"setting:live:minimalEffect", "MINIMAL_EFFECT")
				:setPosition(0, 64+12),
			numberSetting(frame, L"setting:live:noteSpeed", "NOTE_SPEED", {min = 400, max = 3000, snap = 50})
				:setPosition(0, 128+12),
			numberSetting(frame, L"setting:live:textScaling", "TEXT_SCALING", {
				min = 50, max = 100, default = 100, snap = 10, div = 100
			})
				:setPosition(0, 192+12),
			switchSetting(frame, L"setting:live:skillPopup", "SKILL_POPUP")
				:setPosition(0, 256+12),
			numberSetting(frame, L"setting:live:vanish", "VANISH_TYPE", {min = 0, max = 2, default = 0, display = vanish})
				:setPosition(0, 320+12)
		}
	end

	-- Score settings
	if self.persist.scoreSetting == nil then
		local frame = newSettingFrame()
		self.persist.scoreFrame = frame
		self.persist.scoreSetting = {
			numberSetting(frame, L"setting:stamina:score", "SCORE_ADD_NOTE", {min = 100, max = 8192})
				:setPosition(0, 12),
			numberSetting(frame, L"setting:stamina:display", "STAMINA_DISPLAY", {min = 1, max = 99})
				:setPosition(0, 64+12),
			switchSetting(frame, L"setting:stamina:noFail", "STAMINA_FUNCTIONAL")
				:setPosition(0, 128+12),
			-- DEBUG v4.0.0-beta3
			numberSetting(frame, "Perfect Accuracy", "PERFECT_ACCURACY", {min = 0, max = 128})
				:setPosition(0, 192+12),
			numberSetting(frame, "Great Accuracy", "GREAT_ACCURACY", {min = 0, max = 128})
				:setPosition(0, 256+12),
			numberSetting(frame, "Good Accuracy", "GOOD_ACCURACY", {min = 0, max = 128})
				:setPosition(0, 320+12),
			numberSetting(frame, "Bad Accuracy", "BAD_ACCURACY", {min = 0, max = 128})
				:setPosition(0, 384+12),
		}
	end

	-- Live UI settings
	if self.persist.liveUIFrame == nil then
		local frame = newSettingFrame()
		local playUI = setting.get("PLAY_UI")
		local elements = {}

		local function setPlayUI(_, value)
			setting.set("PLAY_UI", value.real)

			for i, v in ipairs(elements) do
				if i == value.index then
					v:setActive(true)
				else
					v:setActive(false)
				end
			end
		end

		for i, v in ipairs(liveUI.enum()) do
			local elem = longSelect(font26, v)
			elem:addEventListener("mousereleased", setPlayUI)
			elem:setData({real = v, index = i})
			if v == playUI then
				elem:setActive(true)
			end
			elements[i] = elem
			frame:addElement(elem, 0, (i - 1) * 64)
		end

		self.persist.liveUIFrame = frame
	end

	-- Language settings
	if self.persist.langFrame == nil then
		local frame = newSettingFrame()
		local elements = {}

		local function setLanguage(elem, value)
			L.set(value.language.code)
			value.instance.persist.currentLanguage = value.language.code

			for _, v in ipairs(elements) do
				if v == elem then
					v:setActive(true)
				else
					v:setActive(false)
				end
			end
		end

		self.persist.previousLanguage = L.get()
		self.persist.currentLanguage = self.persist.previousLanguage
		for i, v in ipairs(L.enum()) do
			local elem = longSelect(font26, string.format("%s (%s)", v.name, v.code))
			elem.width = 678 -- uh
			elem:addEventListener("mousereleased", setLanguage)
			elem:setData({language = v, instance = self})

			if v.code == self.persist.previousLanguage then
				elem:setActive(true)
			end

			elements[i] = elem
			frame:addElement(elem, 0, (i - 1) * 64)
		end

		self.persist.langFrame = frame
	end

	-- System Information
	if self.persist.sysinfoFrame == nil then
		self.persist.sysinfoFrame = newSettingFrame()
		self.persist.sysinfoFrame:addElement(textUI, 4, 0, font16, systemInfo(), 674)
	end

	-- About
	if self.persist.aboutFrame == nil then
		self.persist.aboutFrame = newSettingFrame()
		self.persist.aboutFrame:addElement(textUI, 4, 0, font16, aboutString, 674)
	end

	-- Setting selection cateogry
	if self.persist.categoryFrame == nil then
		self.persist.categoryFrame = glow.frame(0, 86, 240, 548)
		self.persist.settings = {
			{L"setting:general", self.persist.generalFrame, self.persist.generalSetting, nil, "settings"},
			{L"setting:volume", self.persist.volumeFrame, self.persist.volumeSetting, nil, "volume"},
			{L"setting:background", self.persist.bgFrame, self.persist.bgSetting, nil, "panorama"},
			{L"setting:noteStyle", self.persist.nsFrame, self.persist.nsSetting, nil, "slowMotion"},
			{L"setting:live", self.persist.liveFrame, self.persist.liveSetting, nil, "contacts"},
			{L"setting:stamina", self.persist.scoreFrame, self.persist.scoreSetting, nil, "whatsHot"},
			{L"setting:liveUI", self.persist.liveUIFrame, {}, nil, "aspectRatio"}, -- empty list
			{L"setting:language", self.persist.langFrame, {}, nil, "language"}, -- empty list
			{L"setting:sysinfo", self.persist.sysinfoFrame, {}, nil, "devInfo"}, -- empty list
			{L"setting:about", self.persist.aboutFrame, {}, nil, "info"}, -- empty list
		}

		local function setSelected(elem, value)
			for i, v in ipairs(self.persist.settings) do
				if i == value then
					v[4]:setActive(true)
					glow.addFrame(v[2])
				else
					v[4]:setActive(false)
					glow.removeFrame(v[2])
				end
			end

			elem:setActive(true)
			self.persist.selectedSetting = value
		end

		for i, v in ipairs(self.persist.settings) do
			local elem = categorySelect(font22, self.assets.images[v[5]], v[1])
			elem:addEventListener("mousereleased", setSelected)
			elem:setData(i)
			self.persist.categoryFrame:addElement(elem, 0, (i - 1) * 48)
			v[4] = elem
		end

		-- Set element position
		self.persist.categoryFrame:setElementPosition(self.persist.settings[9][4], 0, 452)
		self.persist.categoryFrame:setElementPosition(self.persist.settings[10][4], 0, 500)
	end
	glow.addFrame(self.persist.categoryFrame)
end

function gameSetting:start()
	-- Settings
	self.persist.selectedSetting = 0
	self.persist.whiteOverlay = 1

	-- General settings
	self.persist.currentTheme = setting.get("COLOR_THEME")

	-- Background settings
	self.persist.backgroundDim = setting.get("LIVESIM_DIM") / 100

	-- Note style settings
	local noteStyle = setting.get("NOTE_STYLE")
	local styleData = {
		opacity = 1,
		noteImage = self.assets.images.note
	}
	local preset = noteStyle % 64
	assert(preset == 63 or (preset > 0 and preset <= MAX_NOTE_STYLE), "Invalid note style")
	if preset == 63 then
		local value = math.floor(noteStyle / 64) % 64
		styleData.noteStyleFrame = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style frame")
		value = math.floor(noteStyle / 4096) % 64
		styleData.noteStyleSwing = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style swing")
		value = math.floor(noteStyle / 262144) % 64
		styleData.noteStyleSimul = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style simul")
	else
		styleData.noteStyleFrame, styleData.noteStyleSwing, styleData.noteStyleSimul = preset, preset, preset
	end
	self.persist.defAttr = self.persist.generalSetting[1]:getValue()
	self.persist.styleData = styleData
	self.persist.styleLayer = {}
	self.persist.nsSetting[1]:setValue(styleData.noteStyleFrame)
	self.persist.nsSetting[2]:setValue(styleData.noteStyleSwing)
	self.persist.nsSetting[3]:setValue(styleData.noteStyleSimul)
	updateStyleData(self)
end

function gameSetting:update(dt)
	self.persist.categoryFrame:update(dt)
	self.persist.whiteOverlay = math.min(math.max(
		self.persist.whiteOverlay + dt * (self.persist.selectedSetting == 3 and -2 or 2),
		0),
		1
	)

	local set = self.persist.settings[self.persist.selectedSetting]
	if set then
		set[2]:update(dt)
		for _, v in ipairs(set[3]) do v:update(dt) end
	end
end

function gameSetting:draw()
	local set = self.persist.settings[self.persist.selectedSetting]

	-- Background setting specific
	if self.persist.whiteOverlay < 1 then
		love.graphics.setColor(color.white)
		love.graphics.draw(self.persist.background)
		love.graphics.setColor(color.compat(0, 0, 0, self.persist.backgroundDim))
		love.graphics.rectangle("fill", -88, -43, 1136, 726)
		love.graphics.setColor(color.white25PT)
		love.graphics.rectangle("fill", 0, 0, 240, 640)

		if set then
			for i = 1, #set[3] do
				love.graphics.rectangle("fill", 246, (i - 1) * 64 + 86, 710, 60, 16, 16)
				love.graphics.rectangle("line", 246, (i - 1) * 64 + 86, 710, 60, 16, 16)
			end
		end
	end

	if self.persist.whiteOverlay > 0 then
		local opacity = interpolation(self.persist.whiteOverlay)
		love.graphics.setColor(color.compat(255, 255, 255, opacity))
		love.graphics.rectangle("fill", -88, -43, 1136, 726)

		if set then
			local theme = colorTheme.get()
			love.graphics.setColor(theme[1], theme[2], theme[3], select(4, color.compat(0, 0, 0, opacity)))
			love.graphics.rectangle("fill", 240, 86, 6, 597)
		end
	end

	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(colorTheme.get())
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(color.white)
	util.drawText(self.data.titleText, 480, 24)

	-- Note style-specific setting
	if self.persist.selectedSetting == 4 then
		local curLayer = self.persist.curStyle
		love.graphics.setColor(color.hex7F7F7F)
		love.graphics.rectangle("fill", 318-64, 400-64, 128, 128, 32, 32)
		love.graphics.rectangle("fill", 603-64, 400-64, 128, 128, 32, 32)
		love.graphics.rectangle("fill", 888-64, 400-64, 128, 128, 32, 32)
		love.graphics.rectangle("fill", 318-64, 560-64, 128, 128, 32, 32)
		love.graphics.rectangle("fill", 603-64, 560-64, 128, 128, 32, 32)
		love.graphics.rectangle("fill", 888-64, 560-64, 128, 128, 32, 32)
		love.graphics.rectangle("line", 318-64, 400-64, 128, 128, 32, 32)
		love.graphics.rectangle("line", 603-64, 400-64, 128, 128, 32, 32)
		love.graphics.rectangle("line", 888-64, 400-64, 128, 128, 32, 32)
		love.graphics.rectangle("line", 318-64, 560-64, 128, 128, 32, 32)
		love.graphics.rectangle("line", 603-64, 560-64, 128, 128, 32, 32)
		love.graphics.rectangle("line", 888-64, 560-64, 128, 128, 32, 32)

		for i = 1, #curLayer do
			local xpos = 318
			local layer = self.persist.curStyle[i]
			local quad = note.quadRegion[layer]
			if note.manager.isUncolorableLayer(layer) then
				love.graphics.setColor(color.white)
			else
				love.graphics.setColor(color.compat(curLayer.color[1], curLayer.color[2], curLayer.color[3], 1))
			end

			local w, h = select(3, quad:getViewport())
			if isSimultaneousLayer(layer) then
				xpos = 888
			elseif note.manager.isSwingLayer(layer) then
				xpos = 603
			end

			love.graphics.draw(self.assets.images.note, quad, xpos, 400, 0, 0.75, 0.75, w*0.5, h*0.5)
		end

		drawLayerAt(self.persist.styleData, self.persist.styleLayer[1], 318, 560)
		drawLayerAt(self.persist.styleData, self.persist.styleLayer[2], 603, 560)
		drawLayerAt(self.persist.styleData, self.persist.styleLayer[3], 888, 560)
	end

	glow.draw()
	self.persist.categoryFrame:draw()

	if set then
		set[2]:draw()
		for _, v in ipairs(set[3]) do v:draw() end
	end
end

gameSetting:registerEvent("keyreleased", function(self, k)
	if k == "escape" then
		return leave(nil, self)
	end
end)

return gameSetting
