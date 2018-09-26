-- Beatmap selection
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local setting = require("setting")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local gui = require("libs.fusion-ui")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local selectButton = require("game.ui.select_button")
local beatmapSelButton = require("game.ui.beatmap_select_button")
local checkbox = require("game.ui.checkbox")

local beatmapList = require("game.beatmap.list")

local beatmapSelect = gamestate.create {
	fonts = {
		status = {"fonts/MTLmr3m.ttf", 22},
		title = {"fonts/MTLmr3m.ttf", 30},
		detail = {"fonts/MTLmr3m.ttf", 16}
	},
	images = {},
	audios = {},
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function setStatusText(self, text)
	if not(self.persist.loadingText) then return end
	self.persist.loadingText:clear()
	if not(text) or #text == 0 then return end

	self.persist.loadingText:add({color.black, text}, -1, -1)
	self.persist.loadingText:add({color.black, text}, 1, 1)
	self.persist.loadingText:add({color.white, text})
end

local function addTextWithShadow(text, str, x, y, intensity)
	x = x or 0 y = y or 0
	intensity = intensity or 1
	text:add({color.black, str}, x-intensity, y-intensity)
	text:add({color.black, str}, x+intensity, y+intensity)
	text:add({color.white, str}, x, y)
end

local function initializeSummary(self, data)
	-- Set
	self.persist.summary = data

	-- Title
	self.persist.titleText:clear()
	addTextWithShadow(self.persist.titleText, data.name)

	-- Beatmap information
	self.persist.beatmapInfo:clear()
	self.persist.beatmapDetailInfo:clear()

	-- Format
	addTextWithShadow(self.persist.beatmapDetailInfo, data.format, 470, 118)
	-- Difficulty
	local diff = "Difficulty: "..(data.difficulty or "Unknown")
	-- Cannot use addTextWithShadow here.
	self.persist.beatmapInfo:addf({color.black, diff}, 270, "left", 470-1, 144-1)
	self.persist.beatmapInfo:addf({color.black, diff}, 270, "left", 470+1, 144+1)
	self.persist.beatmapInfo:addf({color.white, diff}, 270, "left", 470, 144)

	-- Score & Combo
	addTextWithShadow(self.persist.beatmapInfo, "Score", 496, 374)
	addTextWithShadow(self.persist.beatmapInfo, "Combo", 652, 374)
	addTextWithShadow(self.persist.beatmapInfo, "S\nA\nB\nC", 470, 400)
	local sstr = (data.scoreS or "-").."\n"..(data.scoreA or "-").."\n"..(data.scoreB or "-").."\n"..(data.scoreC or "-")
	addTextWithShadow(self.persist.beatmapInfo, sstr, 496, 400)
	sstr = (data.comboS or "-").."\n"..(data.comboA or "-").."\n"..(data.comboB or "-").."\n"..(data.comboC or "-")
	addTextWithShadow(self.persist.beatmapInfo, sstr, 652, 400)

	-- Cover art
	if data.coverArt then
		if data.coverArt.image then
			self.persist.beatmapCover = love.graphics.newImage(data.coverArt.image, {mipmaps = true})
		else
			self.persist.beatmapCover = ""
		end

		if data.coverArt.info then
			addTextWithShadow(self.persist.beatmapDetailInfo, data.coverArt.info, 470, 342, 0.5)
		end
	else
		self.persist.beatmapCover = ""
	end
end

local function initializeBeatmapListUI(self)
	if not(self.persist.beatmapList) then return end

	local frameElements = {}
	local frameLayout = {}
	local frameButton2Beatmap = {}

	local function frameButtonCallback(frame)
		local beatmap = frameButton2Beatmap[frame]
		beatmapList.getSummary(beatmap.id, function(data)
			self.persist.selectedBeatmapID = beatmap.id
			return initializeSummary(self, data)
		end)
	end

	for i = 1, #self.persist.beatmapList do
		local v = self.persist.beatmapList[i]
		-- TODO callback
		local element = beatmapSelButton.new(v.name, v.format, frameButtonCallback, v.difficulty)
		frameButton2Beatmap[element] = v
		frameElements[#frameElements + 1] = {
			element = element,
			index = i
		}
		frameLayout[i] = {
			position = "absolute",
			size = "absolute",
			left = 0,
			top = (i - 1) * 60,
			w = 324,
			h = 60
		}
	end

	self.data.beatmapFrame = gui.element.newElement("frame", {
		elements = frameElements,
		layout = frameLayout
	}, {
		backgroundColor = {0, 0, 0, 0},
		padding = {0, #self.persist.beatmapList * 60, 0, 0},
		margin = {0, 0, 0, 0}
	})
	setStatusText(self)
end

function beatmapSelect:load()
	beatmapSelButton.init()

	if self.data.back == nil then
		self.data.back = backNavigation.new("Select Beatmap", leave)
	end
	if self.data.background == nil then
		self.data.background = backgroundLoader.load(1)
	end
	if self.data.openBeatmap == nil then
		local saveUrl = "file://"..love.filesystem.getSaveDirectory().."/beatmap"
		self.data.openBeatmap = selectButton.new("Open Beatmap Directory")
		self.data.openBeatmap:addEventListener("released", function()
			return love.system.openURL(saveUrl)
		end)
	end
	if self.data.beatmapFrame == nil then
		initializeBeatmapListUI(self)
	end
	if self.data.playButton == nil then
		--self.persist.summary
		self.data.playButton = selectButton.new("Play Beatmap")
		self.data.playButton:addEventListener("released", function()
			if self.persist.summary then
				gamestate.enter(loadingInstance.getInstance(), "livesim2", {
					summary = self.persist.summary,
					beatmapName = self.persist.selectedBeatmapID
				})
			end
		end)
	end

	if self.data.checkLabel == nil then
		self.data.checkLabel = love.graphics.newText(self.assets.fonts.status)
		addTextWithShadow(self.data.checkLabel, "Autoplay", 770, 372)
		addTextWithShadow(self.data.checkLabel, "Random", 770, 408)
		addTextWithShadow(self.data.checkLabel, "Storyboard", 770, 444)
		addTextWithShadow(self.data.checkLabel, "Video Bg.", 770, 480)
	end

	if self.data.checkButton == nil then
		self.data.checkButton = {
			checkbox.new(setting.get("AUTOPLAY") == 1, function(_, elem)
				setting.set("AUTOPLAY", elem.type.state and 1 or 0)
			end),
			checkbox.new(false),
			checkbox.new(false),
			checkbox.new(false)
		}
	end
end

function beatmapSelect:start()
	self.persist.beatmapList = {}
	self.persist.loadingText = love.graphics.newText(self.assets.fonts.status)
	self.persist.beatmapInfo = love.graphics.newText(self.assets.fonts.status)
	self.persist.beatmapDetailInfo = love.graphics.newText(self.assets.fonts.detail)
	self.persist.titleText = love.graphics.newText(self.assets.fonts.title)
	beatmapList.push()
	beatmapList.enumerate(function(id, name, fmt, diff)
		if id == "" then
			initializeBeatmapListUI(self)
			setStatusText(self)
			return false
		end
		self.persist.beatmapList[#self.persist.beatmapList + 1] = {
			name = name,
			format = fmt,
			difficulty = diff,
			id = id
		}
		return true
	end)
	setStatusText(self, "Loading...")
end

function beatmapSelect.exit()
	beatmapList.pop()
end

function beatmapSelect.update()
end

function beatmapSelect:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.persist.loadingText, 64, 560)
	love.graphics.draw(self.persist.titleText, 470, 88)
	love.graphics.draw(self.persist.beatmapInfo)
	love.graphics.draw(self.persist.beatmapDetailInfo)
	if self.persist.beatmapCover == "" then
		love.graphics.rectangle("fill", 738, 144, 192, 192)
	elseif self.persist.beatmapCover ~= nil then
		local w, h = self.persist.beatmapCover:getDimensions() -- should be cached, but who cares.
		love.graphics.draw(self.persist.beatmapCover, 738, 144, 0, 192/w, 192/h)
	end

	-- GUI draw
	backNavigation.draw(self.data.back)
	selectButton.draw(self.data.openBeatmap, 64, 592)

	if self.data.beatmapFrame then
		self.data.beatmapFrame:draw(60, 80, 360, 480)
	end

	for i = 1, #self.data.checkButton do
		checkbox.draw(self.data.checkButton[i], 738, 336 + i * 36)
	end
	love.graphics.draw(self.data.checkLabel)

	if self.persist.summary then
		selectButton.draw(self.data.playButton, 470, 520)
	end

	gui.draw()
end

beatmapSelect:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return beatmapSelect
