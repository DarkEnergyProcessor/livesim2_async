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

function beatmapSelect:load()
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
end

function beatmapSelect:start()
	self.persist.beatmapList = {}
	beatmapList.push()
	beatmapList.enumerate(function(id, name, fmt)
		print("beatmap", id, name, fmt)
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
	selectButton.draw(self.data.openBeatmap, 64, 592)
	gui.draw()
end

beatmapSelect:registerEvent("keyreleased", function(self, key)
	if key == "escape" then
		return leave()
	end
end)

return beatmapSelect
