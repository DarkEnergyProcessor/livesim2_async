-- Live result display
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local lsr = require("libs.lsr")

local color = require("color")
local setting = require("setting")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local util = require("util")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local result = require("game.live.result")

local resultScreen = gamestate.create {
	fonts = {}, images = {}
}

function resultScreen:load(arg)
	-- arg contains:
	-- * name - beatmap name
	-- * summary - beatmap summary
	-- * replay - replay object
	-- * livesim2 - Live Simulator: 2 argument (or nil)
	-- * allowRetry - Allow hold to retry?
	-- * allowSave - Allow replay savig?
	-- * autoplay - Is result from autoplay?
	-- * comboRange - Score and combo range
	-- * background - Beatmap background
	glow.clear()

	local comboRange = arg.comboRange or {
		math.ceil(arg.replay.totalNotes * 0.3),
		math.ceil(arg.replay.totalNotes * 0.5),
		math.ceil(arg.replay.totalNotes * 0.7),
		arg.replay.totalNotes
	}

	self.data.background = arg.background or backgroundLoader.load(setting.get("BACKGROUND_IMAGE"))
	self.data.result = result(arg.name)
	self.data.result:setReplayCallback(function()
		if not(arg.autoplay) then
			gamestate.replace(loadingInstance.getInstance(), "livesim2", {
				summary = arg.summary,
				beatmapName = arg.name,
				replay = arg.replay,
				allowRetry = not(arg.allowRetry),
			})
		end
	end)
	self.data.result:setSaveReplayCallback(function()
		if not(arg.allowSave) then return "" end
		if arg.autoplay then
			return L"livesim2:replay:errorAutoplay"
		end

		local name
		if not(love.filesystem.createDirectory("replays/"..arg.name)) then
			return L"livesim2:replay:errorDirectory"
		end

		if arg.replay.filename then
			return L"livesim2:replay:errorAlreadySaved"
		end

		name = "replays/"..arg.name.."/"..arg.replay.timestamp..".lsr"
		if util.fileExists(name) then
			return L"livesim2:replay:errorAlreadySaved"
		end

		local s = lsr.saveReplay(
			name,
			arg.summary.hash,
			arg.replay,
			arg.replay.accuracy,
			arg.replay.events
		)
		if s then
			arg.replay.filename = name
			return L"livesim2:replay:saved"
		else
			return L"livesim2:replay:errorSaveGeneric"
		end
	end)
	self.data.result:setReturnCallback(function(_, restart)
		if restart then
			if arg.allowRetry then
				return gamestate.replace(loadingInstance.getInstance(), "livesim2", arg.livesim2)
			end
		else
			return gamestate.leave(loadingInstance.getInstance())
		end
	end, nil, not(arg.allowRetry))
	self.data.result:setInformation(arg.replay, arg.replay.accuracy, comboRange)

	self.persist.windowWidth, self.persist.windowHeight = love.graphics.getDimensions()
end

function resultScreen:update(dt)
	self.data.result:update(dt)
end

function resultScreen:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.push()
	love.graphics.origin()
	love.graphics.setColor(color.black75PT)
	love.graphics.rectangle("fill", 0, 0, self.persist.windowWidth, self.persist.windowHeight)
	love.graphics.pop()
	self.data.result:draw()
end

resultScreen:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return gamestate.leave(loadingInstance.getInstance())
	end
end)

resultScreen:registerEvent("resize", function(self, w, h)
	self.persist.windowWidth, self.persist.windowHeight = w, h
end)

return resultScreen
