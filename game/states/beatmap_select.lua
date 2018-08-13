-- Beatmap selection
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local gui = require("libs.fusion-ui")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("ui.back_navigation")
local selectButton = require("ui.select_button")
local beatmapSelButton = require("ui.beatmap_select_button")

local beatmapList = require("game.beatmap.list")

local beatmapSelect = gamestate.create {
	fonts = {
		status = {"fonts/MTLmr3m.ttf", 22}
	},
	images = {},
	audios = {},
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function initializeBeatmapListUI(self)
	if not(self.persist.beatmapList) then return end

	local frameElements = {}
	local frameLayout = {}

	for i = 1, #self.persist.beatmapList do
		local v = self.persist.beatmapList[i]
		-- TODO callback
		frameElements[#frameElements + 1] = {
			element = beatmapSelButton.new(v.name, v.format, function() end),
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
		margin = {0, 0, 0, 0},
		w = 350,
		h = 480
	})
	--print(self.data.beatmapFrame.type.w, self.data.beatmapFrame.type.h)
	self.data.beatmapFrame.xoffset, self.data.beatmapFrame.yoffset = -5, -5
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
end

function beatmapSelect:start()
	self.persist.beatmapList = {}
	beatmapList.push()
	beatmapList.enumerate(function(id, name, fmt)
		--print("beatmap", id, name, fmt)
		if id == "" then
			initializeBeatmapListUI(self)
			return false
		end
		self.persist.beatmapList[#self.persist.beatmapList + 1] = {
			name = name,
			format = fmt
		}
		return true
	end)
end

function beatmapSelect:exit()
	beatmapList.pop()
end

function beatmapSelect:update(dt)
end

function beatmapSelect:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	backNavigation.draw(self.data.back)
	if self.data.beatmapFrame then
		self.data.beatmapFrame:draw(60, 80, 350, 480)
	end
	selectButton.draw(self.data.openBeatmap, 64, 592)
	gui.draw()
end

beatmapSelect:registerEvent("keyreleased", function(self, key)
	if key == "escape" then
		return leave()
	end
end)

return beatmapSelect
