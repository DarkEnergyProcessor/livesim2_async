-- Beatmap selection
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local setting = require("setting")
local L = require("language")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local glow = require("game.afterglow")
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
	local diff = L("beatmapSelect:difficulty", {difficulty = data.difficulty or L("beatmapSelect:diffUnknown")})
	-- Cannot use addTextWithShadow here.
	self.persist.beatmapInfo:addf({color.black, diff}, 270, "left", 470-1, 144-1)
	self.persist.beatmapInfo:addf({color.black, diff}, 270, "left", 470+1, 144+1)
	self.persist.beatmapInfo:addf({color.white, diff}, 270, "left", 470, 144)

	-- Score & Combo
	addTextWithShadow(self.persist.beatmapInfo, L"general:score", 496, 374)
	addTextWithShadow(self.persist.beatmapInfo, L"general:combo", 652, 374)
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
			-- cannot use addTextWithShadow (requires automatic break)
			self.persist.beatmapDetailInfo:addf({color.black, data.coverArt.info}, 474, "left", 470-0.5, 338-0.5)
			self.persist.beatmapDetailInfo:addf({color.black, data.coverArt.info}, 474, "left", 470+0.5, 338+0.5)
			self.persist.beatmapDetailInfo:addf({color.white, data.coverArt.info}, 474, "left", 470, 338)
		end
	else
		self.persist.beatmapCover = ""
	end
end

local function beatmapButtonCallback(_, value)
	beatmapList.getSummary(value.beatmap.id, function(data)
		value.instance.persist.selectedBeatmapID = value.beatmap.id
		return initializeSummary(value.instance, data)
	end)
end

local function initializeBeatmapListUI(self)
	if not(self.persist.beatmapList) then return end

	-- Async wrap
	coroutine.wrap(function()
		local frame = glow.frame(0, 80, 460, 480)

		for i = 1, #self.persist.beatmapList do
			local v = self.persist.beatmapList[i]
			-- TODO callback
			local element = beatmapSelButton(v.name, v.format, v.difficulty)
			element:addEventListener("mousereleased", beatmapButtonCallback)
			element:setData({instance = self, beatmap = v})
			frame:addElement(element, 60, (i - 1) * 60)
		end

		self.data.beatmapFrame = frame
		glow.addFrame(frame)
		setStatusText(self)
	end)()
end

local function openBeatmapDirCallback(_, url)
	love.system.openURL(url)
end

local function playButtonCallback(_, self)
	if self.persist.summary then
		gamestate.enter(loadingInstance.getInstance(), "livesim2", {
			summary = self.persist.summary,
			beatmapName = self.persist.selectedBeatmapID
		})
	end
end

function beatmapSelect:load()
	glow.clear()

	if self.data.back == nil then
		self.data.back = backNavigation(L"beatmapSelect:title", leave)
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 0, 0)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(1)
	end

	if self.data.openBeatmap == nil then
		self.data.openBeatmap = selectButton(L"beatmapSelect:openDir")
		self.data.openBeatmap:addEventListener("mousereleased", openBeatmapDirCallback)
		self.data.openBeatmap:setData("file://"..love.filesystem.getSaveDirectory().."/beatmap")
	end
	glow.addElement(self.data.openBeatmap, 64, 592)

	if self.data.beatmapFrame == nil then
		initializeBeatmapListUI(self)
	end

	if self.data.playButton == nil then
		--self.persist.summary
		self.data.playButton = selectButton(L"beatmapSelect:play")
		self.data.playButton:addEventListener("mousereleased", playButtonCallback)
		self.data.playButton:setData(self)
	end
	glow.addElement(self.data.playButton, 470, 520)

	if self.data.checkLabel == nil then
		self.data.checkLabel = love.graphics.newText(self.assets.fonts.status)
		addTextWithShadow(self.data.checkLabel, L"beatmapSelect:optionAutoplay", 770, 372)
		addTextWithShadow(self.data.checkLabel, L"beatmapSelect:optionRandom", 770, 408)
		addTextWithShadow(self.data.checkLabel, L"beatmapSelect:optionStoryboard", 770, 444)
		addTextWithShadow(self.data.checkLabel, L"beatmapSelect:optionVideo", 770, 480)
	end

	if self.data.checkButton == nil then
		self.data.checkButton = {
			checkbox(setting.get("AUTOPLAY") == 1),
			checkbox(false),
			checkbox(false),
			checkbox(false)
		}
		self.data.checkButton[1]:addEventListener("changed", function(_, _, value)
			setting.set("AUTOPLAY", value and 1 or 0)
		end)
	end
	for i = 1, 4 do
		glow.addElement(self.data.checkButton[i], 738, 336 + i * 36)
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
	setStatusText(self, L"beatmapSelect:loading")
end

function beatmapSelect.exit()
	beatmapList.pop()
end

function beatmapSelect:update(dt)
	if self.data.beatmapFrame then
		self.data.beatmapFrame:update(dt)
	end
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
	love.graphics.draw(self.data.checkLabel)

	-- GUI draw
	if self.data.beatmapFrame then
		self.data.beatmapFrame:draw()
	end
	glow.draw()
end

beatmapSelect:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return beatmapSelect
