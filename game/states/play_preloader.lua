-- CLI play preloader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local lsr = require("libs.lsr")
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
	-- arg[2] is the absolute/relative mode
	if not(self.persist.alreadyLoaded) then
		beatmapList.push()

		self.data.beatmapData = nil
		self.data.beatmapName = nil

		if arg[2] then
			beatmapList.registerAbsolute(arg[1], function(name, summary)
				self.data.beatmapName = name
				self.data.beatmapData = summary
			end)
		else
			beatmapList.enumerate() -- initialize
			beatmapList.getSummary(arg[1], function(data)
				self.data.beatmapData = data
				self.data.beatmapName = arg[1]

				if arg.replay then
					self.data.replayData = lsr.loadReplay("replays/"..arg[1].."/"..arg.replay..".lsr", data.hash)
					if self.data.replayData == nil then
						error("cannot load replay file")
					end
				end
			end)
		end

		while self.data.beatmapData == nil do
			async.wait()
		end

		self.persist.alreadyLoaded = true
		self.persist.autoplayMode = arg.autoplay
	end
end

function playPreloader:start(arg)
	local rnd
	if arg.random then
		if type(arg.random) == "boolean" then
			rnd = {}
		else
			rnd = arg.random
		end
	end

	gamestate.replace(loadingInstance.getInstance(), "livesim2", {
		beatmapName = self.data.beatmapName,
		summary = self.data.beatmapData,
		autoplay = self.persist.autoplayMode,
		replay = self.data.replayData,
		random = not(not(arg.random)),
		randomseed = rnd,
	})
end

function playPreloader.resume()
	gamestate.leave(loadingInstance.getInstance())
end

return playPreloader
