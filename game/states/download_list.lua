-- Beatmap Download List
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local utf8 = require("utf8")
local Luaoop = require("libs.Luaoop")
local JSON = require("libs.JSON")
local lily = require("libs.lily")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local async = require("async")
local color = require("color")
local mainFont = require("font")
local util = require("util")
local L = require("language")

local download = require("game.dm")
local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")

local beatmapDownload = gamestate.create {
	images = {}, fonts = {}
}

local beatmapButton = Luaoop.class("Livesim2.BeatmapDLSelectButtonUI", glow.element)

function beatmapButton:new(name, member)
	local font = mainFont.get(22)
	local textBuilder = {}

	-- break text
	do
		local txt = {}
		for _, c in utf8.codes(name) do
			txt[#txt + 1] = utf8.char(c)
			local cat = table.concat(txt)

			if font:getWidth(cat) >= 294 then
				textBuilder[#textBuilder + 1] = cat

				for j = #txt, 1, -1 do
					txt[j] = nil
				end
			end
		end

		if #txt > 0 then
			textBuilder[#textBuilder + 1] = table.concat(txt)
		end
	end

	local usedText = table.concat(textBuilder, "\n")
	self.width, self.height = 310, 64
	self.isPressed = false
	self.text = love.graphics.newText(font)
	self.text:add({color.black, usedText}, 8, 32 - font:getHeight() * #textBuilder * 0.5)

	-- default color
	self.colorNormal = color.white70PT
	self.colorPressed = color.white92PT
	if member == 1 then
		-- Myus color
		self.colorNormal = color.hotPink70PT
		self.colorPressed = color.hotPink92PT
	elseif member == 2 then
		-- Aqours color
		self.colorNormal = color.dodgerBlue70PT
		self.colorPressed = color.dodgerBlue92PT
	elseif member == 3 then
		-- Why tho
		self.colorNormal = color.lightPink70PT
		self.colorPressed = color.navajoWhite92PT
	end

	self:addEventListener("mousepressed", beatmapButton._pressed)
	self:addEventListener("mousecanceled", beatmapButton._released)
	self:addEventListener("mousereleased", beatmapButton._released)
end

function beatmapButton:_pressed()
	self.isPressed = true
end

function beatmapButton:_released()
	self.isPressed = false
end

function beatmapButton:render(x, y)
	love.graphics.setColor(self.isPressed and self.colorPressed or self.colorNormal)
	love.graphics.rectangle("fill", x, y, self.width, self.height)
	love.graphics.rectangle("line", x, y, self.width, self.height)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.text, x, y)
end

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function beatmapDownload:load()
	glow.clear()

	if self.data.frame == nil then
		self.data.frame = glow.frame(0, 68, 960, 512)
	end
	self.data.frame:clear()
	glow.addFrame(self.data.frame)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"beatmapSelect:download:title")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 0, 0)

	if self.data.statusText == nil then
		self.data.statusText = love.graphics.newText(mainFont.get(22))
		if self.persist.statusText then
			util.addTextWithShadow(self.data.statusText, self.persist.statusText, 52, 590)
		end
	end
end

local function setStatusText(self, fmt, ...)
	self.data.statusText:clear()

	if fmt then
		local str = string.format(fmt, ...)
		util.addTextWithShadow(self.data.statusText, str, 52, 590)
		self.persist.statusText = str
	end
end

local function initializeBeatmapList(self, mapdata, etag)
	if not(mapdata) then
		-- Load maps.json
		local sync = async.syncLily(lily.decompress("zlib", love.filesystem.newFileData("maps.json")))
		sync:sync()
		print("get mapdata")
		local oof = sync:getValues()
		print("get mappdata 2", oof:sub(1, 50))
		mapdata = JSON:decode(sync:getValues())
		print("get mapdata ok")
	elseif etag then
		-- Save maps.json
		local mapString = love.filesystem.newFileData(mapdata, "")
		local sync = async.syncLily(lily.compress("zlib", mapString, 9))
		sync:sync()
		love.filesystem.write("maps.json.etag", etag)
		love.filesystem.write("maps.json", sync:getValues())
		mapdata = JSON:decode(mapdata)
	end

	local liveTrack = {}
	for _, v in ipairs(mapdata) do
		-- Ignore it if it's TECHNICAL difficulty
		if v.difficulty_text ~= "TECHNICAL" then
			-- According to ieb, if the `live_difficulty_id` is 20000 and later
			-- then it's SIFAC beatmap.
			if v.live_setting_id >= 20000 then
				v.difficulty_text = "SIFAC"
			end

			local trackidx
			-- Find the live track
			for j = 1, #liveTrack do
				if liveTrack[j].track == v.live_track_id then
					trackidx = liveTrack[j]
					break
				end
			end

			if not(trackidx) then
				trackidx = {}
				liveTrack[#liveTrack + 1] = trackidx

				trackidx.track = v.live_track_id
				trackidx.name = v.name
				trackidx.song = v.sound_asset
				trackidx.icon = v.live_icon_asset
				trackidx.member = v.member_category
				trackidx.live = {}
				if trackidx.name:find("* ", 1, true) == 1 then
					-- Unofficial romaji, but we don't care ¯\_(ツ)_/¯
					trackidx.name = trackidx.name:sub(3)
				end
			end

			-- Create information data
			local infodata = {}
			trackidx.live[v.difficulty_text] = infodata

			-- in C, B, A, S format
			infodata.score = {}
			infodata.score[1], infodata.score[2] = v.c_rank_score, v.b_rank_score
			infodata.score[3], infodata.score[4] = v.a_rank_score, v.s_rank_score
			infodata.combo = {}
			infodata.combo[1], infodata.combo[2] = v.c_rank_combo, v.b_rank_combo
			infodata.combo[3], infodata.combo[4] = v.a_rank_combo, v.s_rank_combo

			-- Background
			infodata.background = math.min(v.stage_level, 12)
			infodata.star = v.stage_level
			if v.member_category == 2 and v.stage_level < 4 then
				infodata.background = 12 + v.stage_level
			end

			-- Livejson info
			infodata.livejson = "livejson/"..v.notes_setting_asset
		end
	end

	self.persist.beatmapListGroup = liveTrack

	-- Setup frame
	for i = 1, #liveTrack do
		local track = liveTrack[i]
		local x = ((i - 1) % 3) * 310
		local y = math.floor((i - 1) / 3) * 64
		local elem = beatmapButton(track.name, track.member)
		-- TODO: add event listener
		self.data.frame:addElement(elem, x, y)
	end
end

local function downloadResponseCallback(self, statusCode, headers, length)
	if statusCode == 304 then
		-- Use local copy
		setStatusText(self, L"beatmapSelect:download:localCopy")
		-- Load local copy using async system
		async.runFunction(initializeBeatmapList):run(self)
	elseif statusCode == 200 then
		self.persist.downloadData = {
			data = {},
			bytesWritten = 0,
			header = headers,
			length = length
		}
	else
		setStatusText(self, L("beatmapSelect:download:errorStatusCode", {code = statusCode}))
	end
end

local function downloadReceiveCallback(self, data)
	local dldata = self.persist.downloadData
	dldata.data[#dldata.data + 1] = data
	dldata.bytesWritten = dldata.bytesWritten + #data

	if dldata.length then
		setStatusText(self, L("beatmapSelect:download:downloadingPercent", dldata))
	end
end

local function downloadFinishCallback(self)
	local dldata = self.persist.downloadData

	-- If dldata is nil, that means it's loaded in responseCallback
	if dldata then
		local mapData = table.concat(dldata.data)
		-- Save map data and initialize
		setStatusText(self, L"beatmapSelect:download:refreshed")
		async.runFunction(initializeBeatmapList):run(self, mapData, dldata.header.etag)
		self.persist.downloadData = nil
	end
end

local function downloadErrorCallback(self, message)
	setStatusText(self, L("beatmapSelect:download:errorGeneric", {message = message}))
	self.persist.downloadData = nil
end

function beatmapDownload:start()
	-- check if maps.json{.etag} exists
	local hasEtag = util.fileExists("maps.json.etag")
	if not(hasEtag and util.fileExists("maps.json")) then
		hasEtag = false
		love.filesystem.remove("maps.json")
		love.filesystem.remove("maps.json.etag")
	end
	-- maps.json cache
	local lastTag
	if hasEtag then
		lastTag = love.filesystem.read("maps.json.etag")
	end

	setStatusText(self, L"beatmapSelect:download:downloading")
	self.persist.download = download()
	:setData(self)
	:setResponseCallback(downloadResponseCallback)
	:setReceiveCallback(downloadReceiveCallback)
	:setFinishCallback(downloadFinishCallback)
	:setErrorCallback(downloadErrorCallback)
	:download("http://r.llsif.win/maps.json", {
		["If-None-Match"] = lastTag
	})
end

function beatmapDownload:update(dt)
	return self.data.frame:update(dt)
end

function beatmapDownload:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.statusText)

	self.data.frame:draw()
	glow.draw()
end

function beatmapDownload:exit()
	self.persist.download:release()
	self.persist.download = nil
end

return beatmapDownload
