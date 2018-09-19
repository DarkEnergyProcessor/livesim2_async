-- CLI play preloader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local async = require("async")
local gamestate = require("gamestate")
local beatmapList = require("game.beatmap.list")
local loadingInstance = require("loading_instance")

local playPreloader = gamestate.create {
	fonts = {},
	images = {},
	audios = {}
}

function playPreloader:load(arg)
	-- arg[1] is the beatmap name
	beatmapList.push()
	beatmapList.enumerate() -- initialize

	self.data.beatmapData = nil
	self.data.beatmapName = nil
	beatmapList.getSummary(arg[1], function(data)
		self.data.beatmapData = data
		self.data.beatmapName = arg[1]
	end)

	while self.data.beatmapData == nil do
		async.wait()
	end
end

function playPreloader:start()
	gamestate.enter(loadingInstance.getInstance(), "livesim2", {
		beatmapName = self.data.beatmapName,
		summary = self.data.beatmapData
	})
end

function playPreloader:resume()
	gamestate.leave()
end

return playPreloader
