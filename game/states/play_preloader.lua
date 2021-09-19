-- CLI play preloader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local lsr = require("libs.lsr")

local Async = require("async")
local Setting = require("setting")
local Gamestate = require("gamestate")
local Render = require("render")

local BeatmapList = require("game.beatmap.list")
local LoadingInstance = require("loading_instance")

local playPreloader = Gamestate.create {
	fonts = {},
	images = {},
	audios = {}
}

function playPreloader:load(arg)
	-- arg[1] is the beatmap name
	-- arg[2] is the absolute/relative mode
	if not(self.persist.alreadyLoaded) then
		BeatmapList.push()

		self.data.beatmapData = nil
		self.data.beatmapName = nil

		if arg[2] then
			BeatmapList.registerAbsolute(arg[1], function(name, summary)
				self.data.beatmapName = name
				self.data.beatmapData = summary
				self.persist.directLoad = true
			end)
		else
			BeatmapList.registerRelative(arg[1], function(name, summary)
				self.data.beatmapData = summary
				self.data.beatmapName = name
				self.persist.directLoad = false

				if arg.replay then
					local hash = summary.hash

					if not(arg.checkHash) then
						hash = nil
					end

					self.data.replayData = assert(lsr.loadReplay("replays/"..name.."/"..arg.replay..".lsr", hash))
				end
			end)
		end

		while self.data.beatmapData == nil do
			Async.wait()
		end

		self.persist.alreadyLoaded = true
		self.persist.autoplayMode = arg.autoplay
		if arg.storyboard == nil then
			self.persist.storyboardMode = Setting.get("STORYBOARD") == 1
		else
			self.persist.storyboardMode = arg.storyboard
		end
	end
end

function playPreloader:start(arg)
	local r = false
	if arg.render then
		Render.initialize(arg.render)
		r = true
	end
	Gamestate.replace(LoadingInstance.getInstance(), "livesim2", {
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
	Gamestate.leave(LoadingInstance.getInstance())
end

return playPreloader
