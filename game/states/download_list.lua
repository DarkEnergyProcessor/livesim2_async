-- Beatmap Download List
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local JSON = require("libs.JSON")

local AssetCache = require("asset_cache")
local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local lily = require("lily")
local log = require("logging")
local Async = require("async")
local color = require("color")
local MainFont = require("main_font")
local Util = require("util")
local L = require("language")

local ColorTheme = require("game.color_theme")
local download = require("game.dm")
local md5 = require("game.md5")

local Glow = require("game.afterglow")
local Ripple = require("game.ui.ripple")
local CircleIconButton = require("game.ui.circle_icon_button")
local ProgressBar = require("game.ui.progress")

local SERVER_ADDRESS = require("game.beatmap.download_address")
local mipmaps = {mipmaps = true}

local beatmapDLSelectButton = Luaoop.class("Livesim2.Download.BeatmapSelectButton", Glow.Element)

do
	local coverShader

	local function commonPressed(self, _, x, y)
		self.isPressed = true
		self.ripple:pressed(x, y)
	end

	local function commonReleased(self)
		self.isPressed = false
		self.ripple:released()
	end

	local defaultColor = {255, 255, 255, color.white}
	function beatmapDLSelectButton:new(state, name, typeID, coverImage)
		coverShader = coverShader or state.data.coverMaskShader

		-- Color from type ID
		local col = ColorTheme[typeID] and ColorTheme[typeID].currentColor or defaultColor
		self.typeColor = col
		self.name = love.graphics.newText(state.data.statusFont)
		self.name:addf({col[4], name}, 310, "left")
		self:setCoverImage(coverImage)

		self.width, self.height = 420, 94
		self.x, self.y = 0, 0
		self.ripple = Ripple(460.691871)
		self.stencilFunc = function()
			love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		end
		self.isPressed = false
		self:addEventListener("mousepressed", commonPressed)
		self:addEventListener("mousereleased", commonReleased)
		self:addEventListener("mousecanceled", commonReleased)
	end

	function beatmapDLSelectButton:setCoverImage(coverImage)
		if coverImage then
			local w, h = coverImage:getDimensions()
			self.coverScaleW, self.coverScaleH = 82 / w, 82 / h
		end

		self.coverImage = coverImage
	end

	function beatmapDLSelectButton:update(dt)
		self.ripple:update(dt)
	end

	function beatmapDLSelectButton:render(x, y)
		local shader = love.graphics.getShader()
		self.x, self.y = x, y

		love.graphics.setColor(color.hex434242)
		love.graphics.rectangle("fill", x, y, self.width, self.height)
		love.graphics.setShader(Util.drawText.workaroundShader)
		love.graphics.setColor(self.typeColor[4])
		love.graphics.draw(self.name, x + 110, y + 20)
		love.graphics.setColor(color.white)

		if self.coverImage then
			love.graphics.setShader(coverShader)
			love.graphics.draw(self.coverImage, x + 6, y + 6, 0, self.coverScaleW, self.coverScaleH)
		else
			love.graphics.setShader()
			love.graphics.setColor(color.hexC4C4C4)
			love.graphics.rectangle("fill", x + 6, y + 6, 82, 82, 12, 12)
			love.graphics.rectangle("line", x + 6, y + 6, 82, 82, 12, 12)
		end

		love.graphics.setShader(shader)

		if self.ripple:isActive() then
			Util.stencil11(self.stencilFunc, "replace", 1, false)
			Util.setStencilTest11("equal", 1)
			self.ripple:draw(self.typeColor[1], self.typeColor[2], self.typeColor[3], x, y)
			Util.setStencilTest11()
		end
	end
end

local function leave()
	return Gamestate.leave(LoadingInstance.getInstance())
end

local function onSelectButton(_, data)
	if data[4].persist.selectedIndex == nil then
		data[4].persist.selectedIndex = data[3]
		Gamestate.enter(nil, "beatmapInfoDL", {data[1], data[2]})
	end
end

local function getHashedName(str)
	local keyhash = Util.stringToHex(md5("The quick brown fox jumps over the lazy dog"..str))
	local filehash = Util.stringToHex(md5(str))
	local strb = {}
	local seed = tonumber(keyhash:sub(1, 8), 16) % 2147483648

	for _ = 1, 20 do
		local chr = math.floor(seed / 33) % 32
		local sel = chr >= 16 and keyhash or filehash
		chr = (chr % 16) + 1
		strb[#strb + 1] = sel:sub(2 * chr - 1, 2 * chr)
		seed = (214013 * seed + 2531011) % 2147483648
	end

	strb[#strb + 1] = str
	return table.concat(strb)
end

local function getLiveIconPath(icon)
	return "live_icon/"..getHashedName(Util.basename(icon))
end

local function handleInvalidCover(path)
	log.errorf("download_list", "cannot load cover '%s', deleting.", path)
	love.filesystem.remove(path)
end

local function loadCoverImage(elem, coverPath)
	local coverImage = AssetCache.loadImage(coverPath, mipmaps, handleInvalidCover)
	elem:setCoverImage(coverImage)
end

local function initializeBeatmapList(self, mapdata, etag)
	if not(mapdata) then
		-- Load maps.json
		local sync = Async.syncLily(lily.decompress("zlib", love.filesystem.newFileData("maps.json")))
		sync:sync()
		mapdata = JSON:decode(sync:getValues())
	elseif etag then
		-- Save maps.json
		local mapString = love.filesystem.newFileData(mapdata, "")
		local sync = Async.syncLily(lily.compress("zlib", mapString, 9))
		love.filesystem.write("maps.json.etag", etag)
		sync:sync()
		love.filesystem.write("maps.json", sync:getValues())
		mapdata = JSON:decode(mapdata)
	end

	self.persist.mapData = mapdata

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
			local infodata = {difficulty = v.difficulty_text}
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
			infodata.livejson = v.notes_setting_asset
		end
	end

	self.persist.beatmapListGroup = liveTrack
	self.persist.beatmapListElem = {}

	-- Setup frame
	for i = 1, #liveTrack do
		local track = liveTrack[i]
		local x = 30 + ((i - 1) % 2) * 480
		local y = math.floor((i - 1) / 2) * 94
		local elem = beatmapDLSelectButton(self, track.name, track.member)
		elem:addEventListener("mousereleased", onSelectButton)
		elem:setData({self.persist.download, track, i, self})
		self.persist.frame:addElement(elem, x, y)
		self.persist.beatmapListElem[i] = elem

		local coverPath = getLiveIconPath(track.icon)
		if Util.fileExists(coverPath) then
			Async.runFunction(loadCoverImage):run(elem, coverPath)
		end
	end
end

local function setStatusText(self, text, blink)
	self.persist.statusText:clear()
	if not(text) or #text == 0 then return end

	self.persist.statusText:add(text, 32, 550)

	if blink then
		if self.persist.statusTextBlink == math.huge then
			self.persist.statusTextBlink = 0
		end
	else
		self.persist.statusTextBlink = math.huge
	end
end

local function downloadResponseCallback(self, statusCode, headers, length)
	if statusCode == 304 then
		Glow.removeElement(self.data.progress)
		setStatusText(self)
		-- Load local copy using async system
		Async.runFunction(initializeBeatmapList):run(self)
	elseif statusCode == 200 then
		self.persist.downloadData = {
			data = {},
			bytesWritten = 0,
			header = headers,
			length = length
		}

		if length then
			self.data.progress:setMaxValue(length)
		end
	else
		self.data.progress:setValue(math.huge)
		setStatusText(self, L("beatmapSelect:download:errorStatusCode", {code = statusCode}))
	end
end

local function downloadReceiveCallback(self, data)
	local dldata = self.persist.downloadData
	if not dldata then return end

	dldata.data[#dldata.data + 1] = data
	dldata.bytesWritten = dldata.bytesWritten + #data

	if dldata and dldata.length then
		self.data.progress:setValue(dldata.bytesWritten)
		setStatusText(self, L("beatmapSelect:download:downloadingBytesProgress", {
			a = dldata.bytesWritten,
			b = dldata.length
		}), true)
	end
end

local function downloadFinishCallback(self)
	local dldata = self.persist.downloadData

	-- If dldata is nil, that means it's loaded in responseCallback or not found.
	if dldata then
		local mapData = table.concat(dldata.data)
		-- Save map data and initialize
		Async.runFunction(initializeBeatmapList):run(self, mapData, dldata.header.etag)
		self.persist.downloadData = nil
		setStatusText(self)
		Glow.removeElement(self.data.progress)
	end
end

local function downloadErrorCallback(self, message)
	setStatusText(self, L("beatmapSelect:download:errorGeneric", {message = message}))
	self.persist.downloadData = nil
	self.data.progress:setValue(math.huge)
end

local beatmapDownload = Gamestate.create {
	images = {
		coverMask = {"assets/image/ui/cover_mask.png", mipmaps},
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmaps},
	}, fonts = {}
}

function beatmapDownload:load()
	Glow.clear()

	self.data.titleFont, self.data.statusFont = MainFont.get(31, 24)

	if self.data.back == nil then
		self.data.back = CircleIconButton(color.hex333131, 36, self.assets.images.navigateBack, 0.48, ColorTheme.get())
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 32, 4)

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = Util.gradient("vertical", color.black75PT, color.transparent)
	end

	if self.data.coverMaskShader == nil then
		self.data.coverMaskShader = love.graphics.newShader("assets/shader/mask.fs")
		self.data.coverMaskShader:send("mask", self.assets.images.coverMask)
	end

	if self.persist.frame == nil then
		self.persist.frame = Glow.Frame(0, 68, 960, 512)
	end

	if self.data.titleText == nil then
		self.data.titleText = love.graphics.newText(self.data.titleFont)
		self.data.titleText:add(L"beatmapSelect:download")
	end

	if self.data.progress == nil then
		self.data.progress = ProgressBar(896, 24)
	end
end

function beatmapDownload:start()
	self.persist.frame = Glow.Frame(0, 80, 960, 560)
	self.persist.frame:setSliderColor(color.hex434242)
	self.persist.frame:setSliderHandleColor(ColorTheme.get())
	Glow.addFrame(self.persist.frame)

	self.persist.statusText = love.graphics.newText(self.data.statusFont)
	self.persist.statusTextBlink = math.huge
	self.persist.selectedIndex = nil

	local hasEtag = Util.fileExists("maps.json.etag")
	if not(hasEtag and Util.fileExists("maps.json")) then
		hasEtag = false
		love.filesystem.remove("maps.json")
		love.filesystem.remove("maps.json.etag")
	end

	-- maps.json cache
	local lastTag
	if hasEtag then
		lastTag = love.filesystem.read("maps.json.etag")
	end

	setStatusText(self, L"beatmapSelect:download:downloading", true)
	self.persist.download = download()
		:setData(self)
		:setResponseCallback(downloadResponseCallback)
		:setReceiveCallback(downloadReceiveCallback)
		:setFinishCallback(downloadFinishCallback)
		:setErrorCallback(downloadErrorCallback)
		:download(SERVER_ADDRESS.."/maps.json", {
			["If-None-Match"] = lastTag
		})
	Glow.addElement(self.data.progress, 32, 584)
end

function beatmapDownload:update(dt)
	self.persist.frame:update(dt)

	if self.persist.statusTextBlink ~= math.huge then
		self.persist.statusTextBlink = (self.persist.statusTextBlink + dt) % 2
	end
end

function beatmapDownload:draw()
	love.graphics.setColor(color.hex434242)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	self.persist.frame:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(color.hex333131)
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.titleText, 112, 24)
	if self.persist.statusTextBlink ~= math.huge then
		love.graphics.setColor(color.compat(255, 255, 255, math.abs(1 - self.persist.statusTextBlink)))
	end
	Util.drawText(self.persist.statusText)

	Glow.draw()
end

function beatmapDownload:resumed()
	Glow.addFrame(self.persist.frame)

	if self.persist.selectedIndex then
		-- Try to set the cover art
		local i = self.persist.selectedIndex
		Async.runFunction(function()
			local track = self.persist.beatmapListGroup[i]
			local coverPath = getLiveIconPath(track.icon)
			if Util.fileExists(coverPath) then
				self.persist.beatmapListElem[i]:setCoverImage(AssetCache.loadImage(coverPath, mipmaps, handleInvalidCover))
			end
		end):run()

		self.persist.selectedIndex = nil
	end
end

return beatmapDownload
