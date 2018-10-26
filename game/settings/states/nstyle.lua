-- Note Style Setting
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local bit = require("bit")
local gamestate = require("gamestate")
local color = require("color")
local loadingInstance = require("loading_instance")
local setting = require("setting")
local L = require("language")

local gui = require("libs.fusion-ui")

local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local numberSetting = require("game.settings.number")

local note = require("game.live.note")

local noteSetting = gamestate.create {
	images = {
		note = {"noteImage:assets/image/tap_circle/notes.png", {mipmaps = true}},
	},
	fonts = {}
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function updateStyleData(self)
	self.persist.styleLayer[1] = note.manager.getLayer(self.persist.styleData, 1, true, true, false, false)
	self.persist.styleLayer[2] = note.manager.getLayer(self.persist.styleData, 2, true, true, false, false)
	self.persist.styleLayer[3] = note.manager.getLayer(self.persist.styleData, 3, true, true, false, false)
	self.persist.styleLayer[4] = note.manager.getLayer(self.persist.styleData, self.persist.defAttr, true, true, false, false)

	-- simultaneous neon doesn't provide base frame if base frame is also neon
	if self.persist.styleData.noteStyleFrame == 2 then
		self.persist.styleLayer[4][#self.persist.styleLayer[4] + 1] = self.persist.defAttr + 16
	end

	-- calculate note style value
	setting.set("NOTE_STYLE", 63 +
		self.persist.styleData.noteStyleFrame * 64 +
		self.persist.styleData.noteStyleSwing * 4096 +
		self.persist.styleData.noteStyleSimul * 262144
	)
end

local tempPosition = {x = 0, y = 0}
local function drawLayerAt(styleData, layer, x, y)
	tempPosition.x, tempPosition.y = x, y
	return note.manager.drawNote(styleData, layer, 1, tempPosition, 1, 0)
end

local function isSwingLayer(layerIndex)
	return
		layerIndex == 15 or
		(layerIndex >= 29 and layerIndex <= 50) or
		(layerIndex >= 63 and layerIndex <= 73)
end

local function isUncolorableLayer(layerIndex)
	return
		(layerIndex >= 1 and layerIndex <= 3) or
		layerIndex == 16 or
		layerIndex == 28 or
		layerIndex == 62
end

local function isSimultaneousLayer(layerIndex)
	return layerIndex == 16 or layerIndex == 28 or layerIndex == 62
end

function noteSetting:load()
	if self.data.settingData == nil then
		self.data.settingData = {
			numberSetting(L"setting:noteStyle:base", nil, {min = 1, max = 3, value = 1})
				:setPosition(61, 60)
				:setChangedCallback(self, function(obj, v)
					obj.persist.styleData.noteStyleFrame = v
					return updateStyleData(obj)
				end),
			numberSetting(L"setting:noteStyle:swing", nil, {min = 1, max = 3, value = 1})
				:setPosition(61, 146)
				:setChangedCallback(self, function(obj, v)
					obj.persist.styleData.noteStyleSwing = v
					return updateStyleData(obj)
				end),
			numberSetting(L"setting:noteStyle:simul", nil, {min = 1, max = 3, value = 1})
				:setPosition(61, 232)
				:setChangedCallback(self, function(obj, v)
					obj.persist.styleData.noteStyleSimul = v
					return updateStyleData(obj)
				end),
		}
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new(L"setting:noteStyle", leave)
	end

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end
end

function noteSetting:start()
	local noteStyle = setting.get("NOTE_STYLE")
	local styleData = {
		opacity = 1,
		noteImage = self.assets.images.note
	}
	local preset = bit.band(noteStyle, 63)
	local MAX_NOTE_STYLE = 3 -- const
	assert(preset == 63 or (preset > 0 and preset <= MAX_NOTE_STYLE), "Invalid note style")
	if preset == 63 then
		local value = bit.band(bit.rshift(noteStyle, 6), 63)
		styleData.noteStyleFrame = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style frame")
		value = bit.band(bit.rshift(noteStyle, 12), 63)
		styleData.noteStyleSwing = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style swing")
		value = bit.band(bit.rshift(noteStyle, 18), 63)
		styleData.noteStyleSimul = assert(value > 0 and value <= MAX_NOTE_STYLE and value, "Invalid note style simul")
	else
		styleData.noteStyleFrame, styleData.noteStyleSwing, styleData.noteStyleSimul = preset, preset, preset
	end

	self.persist.defAttr = setting.get("LLP_SIFT_DEFATTR")
	self.persist.styleData = styleData
	self.persist.styleLayer = {}
	self.data.settingData[1]:setValue(styleData.noteStyleFrame)
	self.data.settingData[2]:setValue(styleData.noteStyleSwing)
	self.data.settingData[3]:setValue(styleData.noteStyleSimul)
	updateStyleData(self)
end

function noteSetting:update(dt)
	for i = 1, #self.data.settingData do
		self.data.settingData[i]:update(dt)
	end
end

function noteSetting:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	backNavigation.draw(self.data.back)

	for i = 1, #self.data.settingData do
		self.data.settingData[i]:draw()
	end

	local curLayer = self.persist.styleLayer[4]
	for i = 1, #curLayer do
		local xpos = 224
		local layer = self.persist.styleLayer[4][i]
		local quad = note.quadRegion[layer]
		if isUncolorableLayer(layer) then
			love.graphics.setColor(color.white)
		else
			love.graphics.setColor(color.compat(curLayer.color[1], curLayer.color[2], curLayer.color[3], 1))
		end

		local w, h = select(3, quad:getViewport())
		if isSimultaneousLayer(layer) then
			xpos = 736
		elseif isSwingLayer(layer) then
			xpos = 480
		end

		love.graphics.draw(self.assets.images.note, quad, xpos, 400, 0, 1, 1, w*0.5, h*0.5)
	end

	drawLayerAt(self.persist.styleData, self.persist.styleLayer[1], 224, 560)
	drawLayerAt(self.persist.styleData, self.persist.styleLayer[2], 480, 560)
	drawLayerAt(self.persist.styleData, self.persist.styleLayer[3], 736, 560)
	gui.draw()
end

noteSetting:registerEvent("keyreleased", function(_, key)
	if key == "escape" then leave() end
end)

return noteSetting
