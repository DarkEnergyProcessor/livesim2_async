-- CLI play preloader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local lsr = require("libs.lsr")

local async = require("async")
local setting = require("setting")
local gamestate = require("gamestate")
local render = require("render")

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
				self.persist.directLoad = true
			end)
		else
			beatmapList.registerRelative(arg[1], function(name, summary)
				self.data.beatmapData = summary
				self.data.beatmapName = name
				self.persist.directLoad = false

				if arg.replay then
					self.data.replayData = assert(lsr.loadReplay("replays/"..name.."/"..arg.replay..".lsr", summary.hash))
				end
			end)
		end

		while self.data.beatmapData == nil do
			async.wait()
		end

		self.persist.alreadyLoaded = true
		self.persist.autoplayMode = arg.autoplay
		if arg.storyboard == nil then
			self.persist.storyboardMode = setting.get("STORYBOARD") == 1
		else
			self.persist.storyboardMode = arg.storyboard
		end
	end
end

function playPreloader:start(arg)
	local r = false
	if arg.render then
		render.initialize(arg.render.output, arg.render.width, arg.render.height)
		r = true
	end
	gamestate.replace(loadingInstance.getInstance(), "livesim2", {
		beatmapName = self.data.beatmapName,
		summary = self.data.beatmapData,
		autoplay = self.persist.autoplayMode,
		storyboard = self.persist.storyboardMode,
		replay = self.data.replayData,
		random = not(not(arg.random)),
		seed = arg.seed,
		direct = self.persist.directLoad,
		render = r
	})
end

function playPreloader.resume()
	gamestate.leave(loadingInstance.getInstance())
end

return playPreloader
