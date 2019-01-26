-- View Replays
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local lsr = require("libs.lsr")

local async = require("async")
local color = require("color")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local log = require("logging")
local mainFont = require("font")
local util = require("util")
local L = require("language")

local backgroundLoader = require("game.background_loader")

local glow = require("game.afterglow")
local backNavigation = require("game.ui.back_navigation")
local longButtonUI = require("game.ui.long_button")

local replayView = gamestate.create {
	images = {}, fonts = {}
}

local function loadReplay(_, value)
	local self = value.instance

	gamestate.enter(loadingInstance.getInstance(), "result", {
		name = self.persist.arg.name,
		summary = self.persist.arg.summary,
		replay = value.replay,
		allowRetry = false,
		allowSave = false,
		autoplay = false,
		comboRange = self.persist.comboRange
	})
end

local function initializeReplayList(self, arg)
	self.data.buttonFrame:clear()
	local list = {}

	assert(love.filesystem.createDirectory("replays/"..arg.name), "failed to create beatmap replay directory")
	for _, v in ipairs(love.filesystem.getDirectoryItems("replays/"..arg.name.."/")) do
		if v:sub(-4) == ".lsr" then
			local replay, s = lsr.loadReplay("replays/"..arg.name.."/"..v, arg.summary.hash)
			if replay then
				list[#list + 1] = {replay = replay, instance = self}
			else
				log.warnf("view.replay", "failed to load replay %s: %s", v, s)
			end
		end
	end

	table.sort(list, function(a, b) return a.replay.timestamp > b.replay.timestamp end)
	for i = 1, #list do
		local v = list[i]
		local date = os.date("%d %B %Y, %H:%M:%S", v.replay.timestamp)
		local elem = longButtonUI(string.format("%s (%s)", date, util.basename(v.replay.filename)))
		elem:addEventListener("mousereleased", loadReplay)
		elem:setData(v)
		self.data.buttonFrame:addElement(elem, 0, (i - 1) * 78)
	end
end

function replayView:load(arg)
	glow.clear()

	if self.persist.replayText == nil then
		self.persist.replayText = love.graphics.newText(mainFont.get(22))
		util.addTextWithShadow(self.persist.replayText, L("beatmapSelect:viewReplay:desc", {beatmapName = arg.name}), 0, 0)
	end

	if self.data.buttonFrame == nil then
		self.data.buttonFrame = glow.frame(101, 80, 758, 516)
	end
	self.data.buttonFrame:clear()
	glow.addFrame(self.data.buttonFrame)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(1)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"beatmapSelect:viewReplay")
		self.data.back:addEventListener("mousereleased", function()
			return gamestate.leave(nil)
		end)
	end
	glow.addFixedElement(self.data.back, 0, 0)
end

function replayView:start(arg)
	if arg.summary.comboS then
		self.persist.comboRange = {
			arg.summary.comboC,
			arg.summary.comboB,
			arg.summary.comboA,
			arg.summary.comboS
		}
	end
	self.persist.arg = arg
	async.runFunction(initializeReplayList):run(self, arg)
end

function replayView:resumed()
	async.runFunction(initializeReplayList):run(self, self.persist.arg)
end

function replayView:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.persist.replayText, 86, 42)

	self.data.buttonFrame:draw()
	glow.draw()
end

return replayView
