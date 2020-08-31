-- Beatmap Downloader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local JSON = require("libs.JSON")
local ls2 = require("libs.ls2")

local async = require("async")
local assetCache = require("asset_cache")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local log = require("logging")
local color = require("color")
local mainFont = require("font")
local setting = require("setting")
local util = require("util")
local md5 = require("game.md5")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local selectButton = require("game.ui.select_button")
local checkbox = require("game.ui.checkbox")

local beatmapList = require("game.beatmap.list")

local beatmapInfoDL = gamestate.create {
	images = {
		titleBar = {"assets/image/ui/title_bar.png", {mipmaps = true}},
		goalInfo = {"assets/image/ui/goals_window.png", {mipmaps = true}}
	}, fonts = {}
}

local SERVER_ADDRESS = require("game.beatmap.download_address")
local difficultyString = {"EASY", "NORMAL", "HARD", "EXPERT", "MASTER", "SIFAC"}

local function createGradientMesh(w, h)
	return love.graphics.newMesh({
		{0, 0, 0, 0, 0, 0, 0, 0},
		{w, 0, 1, 0, 0, 0, 0, 0},
		{w, h, 1, 1, 0, 0, 0, color.black[4] * 0.75},
		{0, h, 0, 1, 0, 0, 0, color.black[4] * 0.75},
	}, "fan", "static")
end

local function setStatusText(self, fmt, ...)
	self.data.statusText:clear()

	if fmt and #fmt > 0 then
		local str = string.format(fmt, ...)
		util.addTextWithShadow(self.data.statusText, str, 296, 460)
		self.persist.statusText = str
	else
		self.persist.statusText = ""
	end
end

local function setTitle(self, title)
	self.data.titleText:clear()
	-- Cannot use util.addTextWithShadow (must be in center)
	self.data.titleText:addf({color.black, title}, 719, "center", 172, 514)
	self.data.titleText:addf({color.white, title}, 719, "center", 170, 512)
end

local function setDifficulty(self, diffname)
	local text = L("beatmapSelect:difficulty", {difficulty = diffname})

	self.data.diffText:clear()
	self.data.diffText:addf({color.black, text}, 719, "center", 171, 571)
	self.data.diffText:addf({color.white, text}, 719, "center", 170, 570)
end

local function setGoalsInfo(self, infodata)
	local a = {color.black, nil}
	local b = {"C", "B", "A", "S"}

	self.data.goalsText:clear()
	a[2] = L"general:score"
	self.data.goalsText:add(a, 710, 76)
	a[2] = L"general:combo"
	self.data.goalsText:addf(a, 226, "right", 710, 76)
	-- Goals
	for i, v in ipairs(b) do
		local y = 104 + (i - 1) * 23
		a[2] = v
		self.data.goalsText:add(a, 682, y)
		a[2] = tostring(infodata.score[i])
		self.data.goalsText:add(a, 710, y)
		a[2] = tostring(infodata.combo[i])
		self.data.goalsText:addf(a, 226, "right", 710, y)
	end
end

local function setBeatmapInfo(_, data)
	local self, diff = data[1], data[2]
	local infodata = self.persist.trackData.live[diff]
	setDifficulty(self, string.format("%s, %d\226\152\134", diff, infodata.star))
	setGoalsInfo(self, infodata)
	self.data.playButton:setData({self, infodata, false})
	self.data.viewReplay:setData({self, infodata, true})
end

local function getHashedName(str)
	local keyhash = util.stringToHex(md5("The quick brown fox jumps over the lazy dog"..str))
	local filehash = util.stringToHex(md5(str))
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

local function getLS2Name(infodata)
	local hashedname = getHashedName(infodata.livejson)
	return hashedname:sub(1, -#infodata.livejson - 1)..".sif."..infodata.difficulty..".ls2"
end

local function getLiveIconPath(self)
	return "live_icon/"..getHashedName(util.basename(self.persist.trackData.icon))
end

local function getAudioPath(self)
	return "audio/"..getHashedName(util.basename(self.persist.trackData.song))
end

local function initializeDifficultyButton(self)
	self.data.diffFrame:clear()
	if not(self.persist.trackData) then return end

	if self.data.diffButtons == nil then
		local diffData = {}

		for i = 1, #difficultyString do
			local diff = difficultyString[i]
			if self.persist.trackData.live[diff] then
				local elem = selectButton(string.format("%s (%d\226\152\134)", diff, self.persist.trackData.live[diff].star))
				elem:addEventListener("mousereleased", setBeatmapInfo)
				elem:setData({self, diff})
				diffData[#diffData + 1] = elem
			end
		end

		self.data.diffButtons = diffData
	end

	for i = 1, #self.data.diffButtons do
		self.data.diffFrame:addElement(self.data.diffButtons[i], 16, (i - 1) * 40)
	end
end

local function beatmapToLS2(self, file, infodata, beatmap)
	local cover = love.filesystem.read(getLiveIconPath(self))

	for i = 1, #beatmap do
		beatmap[i].timing_sec = beatmap[i].timing_sec + setting.get("DOWNLOAD_OFFSET") / 1000
	end

	-- New LS2 writer
	ls2.encoder.new(file, {
		name = self.persist.trackData.name,
		song_file = getAudioPath(self),
		star = infodata.star,
		score = infodata.score,
		combo = infodata.combo
	})
	-- Set background image
	:set_background_id(infodata.star)
	-- Add beatmap
	:add_beatmap(beatmap)
	-- Add cover art
	:add_cover_art({
		image = cover,
		title = self.persist.trackData.name
	})
	-- Write
	:write()
end

local function downloadCoverArt(self)
	if self.persist.isCoverDownloading or self.data.coverArt then return end
	self.persist.isCoverDownloading = true
	setStatusText(self, L"beatmapSelect:download:downloadingCoverArt")

	local coverPath = getLiveIconPath(self)
	local coverLength
	local coverWritten = 0
	local file
	self.persist.download
	:setResponseCallback(function(_, statusCode, _, length)
		if statusCode == 200 then
			coverLength = length
			file = love.filesystem.newFile(coverPath, "w")
		else
			self.persist.isCoverDownloading = false
			setStatusText(self, L("beatmapSelect:download:errorStatusCode", {code = statusCode}))
		end
	end)
	:setReceiveCallback(function(_, data)
		if self.persist.isCoverDownloading then
			file:write(data)
			if coverLength then
				coverWritten = coverWritten + #data
				setStatusText(self, "%s (%d/%d bytes)", L"beatmapSelect:download:downloadingCoverArt", coverWritten, coverLength)
			end
		end
	end)
	:setFinishCallback(function(_)
		if self.persist.isCoverDownloading then
			file:close()
			async.runFunction(function()
				self.data.coverArt = assetCache.loadImage(coverPath, {mipmaps = true})
			end):run()
			setStatusText(self, L"beatmapSelect:download:ready")
			self.persist.isCoverDownloading = false
		end
	end)
	:setErrorCallback(function(_, msg)
		if file then file:close() end
		if self.persist.isCoverDownloading then
			setStatusText(self, L("beatmapSelect:download:errorGeneric", {message = msg}))
		end
		self.persist.isCoverDownloading = false
	end)
	:download(SERVER_ADDRESS.QUERY.."/"..self.persist.trackData.icon)
end

local function downloadBeatmap(self, infodata, dest)
	if self.persist.isBeatmapDownloading then return end
	self.persist.isBeatmapDownloading = true
	setStatusText(self, L("beatmapSelect:download:downloadingBeatmap", {difficulty = infodata.difficulty}))

	local length
	local written = 0
	local jsonData = {}
	self.persist.download
	:setResponseCallback(function(_, statusCode, _, len)
		if statusCode == 200 then
			length = len
		else
			self.persist.isBeatmapDownloading = false
			setStatusText(self, L("beatmapSelect:download:errorStatusCode", {code = statusCode}))
		end
	end)
	:setReceiveCallback(function(_, data)
		if self.persist.isBeatmapDownloading then
			jsonData[#jsonData + 1] = data
			if length then
				written = written + #data
				local str = L("beatmapSelect:download:downloadingBeatmap", {difficulty = infodata.difficulty})
				setStatusText(self, "%s (%d/%d bytes)", str, written, length)
			end
		end
	end)
	:setFinishCallback(function(_)
		if self.persist.isBeatmapDownloading then
			self.persist.isBeatmapDownloading = false
			beatmapToLS2(self, love.filesystem.newFile(dest, "w"), infodata, JSON:decode(table.concat(jsonData)))
			setStatusText(self, L"beatmapSelect:download:ready")
		end
	end)
	:setErrorCallback(function(_, msg)
		if self.persist.isBeatmapDownloading then
			setStatusText(self, L("beatmapSelect:download:errorGeneric", {message = msg}))
		end
		self.persist.isBeatmapDownloading = false
	end)
	:download(SERVER_ADDRESS.LIVEJSON.."/"..infodata.livejson)
end

local function downloadAudio(self, infodata, dest)
	if self.persist.isAudioDownloading then return end
	self.persist.isAudioDownloading = true
	setStatusText(self, L"beatmapSelect:download:downloadingAudio")

	local length
	local written = 0
	local file
	self.persist.download
	:setResponseCallback(function(_, statusCode, _, len)
		if statusCode == 200 then
			length = len
			file = love.filesystem.newFile(dest, "w")
		else
			self.persist.isAudioDownloading = false
			setStatusText(self, L("beatmapSelect:download:errorStatusCode", {code = statusCode}))
		end
	end)
	:setReceiveCallback(function(_, data)
		if self.persist.isAudioDownloading then
			file:write(data)
			if length then
				written = written + #data
				setStatusText(self, "%s (%d/%d bytes)", L"beatmapSelect:download:downloadingAudio", written, length)
			end
		end
	end)
	:setFinishCallback(function(_)
		if self.persist.isAudioDownloading then
			self.persist.isAudioDownloading = false
			file:close()

			-- Try to download beatmap
			local beatmapFile = "beatmap/"..getLS2Name(infodata)
			if util.fileExists(beatmapFile) then
				setStatusText(self, L"beatmapSelect:download:ready")
			else
				downloadBeatmap(self, infodata, beatmapFile)
			end
		end
	end)
	:setErrorCallback(function(_, msg)
		if file then file:close() end
		if self.persist.isAudioDownloading then
			setStatusText(self, L("beatmapSelect:download:errorGeneric", {message = msg}))
		end
		self.persist.isAudioDownloading = false
	end)
	:download(SERVER_ADDRESS.QUERY.."/"..self.persist.trackData.song)
end

local function selectPlayButton(_, data)
	local self, infodata = data[1], data[2]

	if infodata == nil then
		setStatusText(self, L"beatmapSelect:download:errorDifficulty")
		return
	end

	if
		self.persist.isCoverDownloading or
		self.persist.isAudioDownloading or
		self.persist.isBeatmapDownloading or
		self.persist.gamestateEntering
	then
		return
	end

	-- If audio file doesn't exists, download it first
	local audioName = getAudioPath(self)
	if not(util.fileExists(audioName)) then
		downloadAudio(self, infodata, audioName)
		return
	end

	-- If beatmap doesn't exists, download it
	local beatmapName = getLS2Name(infodata)
	local beatmapNamePath = "beatmap/"..beatmapName
	if not(util.fileExists(beatmapNamePath)) then
		downloadBeatmap(self, infodata, beatmapNamePath)
		return
	end

	-- Okay play beatmap
	self.persist.gamestateEntering = true
	beatmapList.registerRelative(beatmapName, function(name, summary)
		if data[3] then
			gamestate.enter(nil, "viewReplay", {
				name = name,
				summary = summary
			})
		else
			gamestate.enter(loadingInstance.getInstance(), "livesim2", {
				beatmapName = name,
				summary = summary,
				random = self.data.randomCheck:isChecked()
			})
		end
	end)
end

local function leave()
	return gamestate.leave(nil)
end

function beatmapInfoDL:load()
	glow.clear()
	local font22 = mainFont.get(22)

	if self.data.titleText == nil then
		self.data.titleText = love.graphics.newText(mainFont.get(36))
		if self.persist.trackData then
			setTitle(self, self.persist.trackData.name)
		end
	end

	if self.data.diffText == nil then
		self.data.diffText = love.graphics.newText(mainFont.get(32))
	end

	if self.data.goalsText == nil then
		self.data.goalsText = love.graphics.newText(font22)
	end

	if self.data.diffFrame == nil then
		self.data.diffFrame = glow.frame(6, 70, 280, 370)
	end
	initializeDifficultyButton(self)
	glow.addFrame(self.data.diffFrame)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(13)
	end

	if self.data.gradient == nil then
		self.data.gradient = createGradientMesh(love.graphics.getDimensions())
	end

	if self.data.back == nil then
		self.data.back = backNavigation(L"beatmapSelect:download:view")
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 0, 0)

	if self.data.autoplayCheck == nil then
		self.data.autoplayCheck = checkbox(setting.get("AUTOPLAY") == 1)
		self.data.autoplayCheck:addEventListener("changed", function(_, _, value)
			setting.set("AUTOPLAY", value and 1 or 0)
		end)
	end
	glow.addElement(self.data.autoplayCheck, 24, 524)

	if self.data.randomCheck == nil then
		self.data.randomCheck = checkbox(false)
	end
	glow.addElement(self.data.randomCheck, 24, 582)

	if self.data.viewReplay == nil then
		self.data.viewReplay = selectButton(L"beatmapSelect:viewReplay")
		self.data.viewReplay:addEventListener("mousereleased", selectPlayButton)
		self.data.viewReplay:setData({self, nil, true})
	end
	glow.addElement(self.data.viewReplay, 710, 302)

	if self.data.playButton == nil then
		self.data.playButton = selectButton(L"beatmapSelect:play")
		self.data.playButton:addEventListener("mousereleased", selectPlayButton)
		self.data.playButton:setData({self, nil, false})
	end
	glow.addElement(self.data.playButton, 710, 382)

	if self.data.statusText == nil then
		self.data.statusText = love.graphics.newText(font22)
		if self.persist.statusText then
			setStatusText(self, self.persist.statusText)
		else
			setStatusText(self, L"beatmapSelect:download:ready")
		end
	end

	if self.data.staticText == nil then
		self.data.staticText = love.graphics.newText(font22)
		util.addTextWithShadow(self.data.staticText, L"beatmapSelect:optionAutoplay", 56, 524)
		util.addTextWithShadow(self.data.staticText, L"beatmapSelect:optionRandom", 56, 582)
	end

	if self.data.coverArt == nil and self.persist.trackData then
		local name = getLiveIconPath(self)
		if util.fileExists(name) then
			self.data.coverArt = assetCache.loadImage(name, {mipmaps = true})
		end
	end
end

function beatmapInfoDL:start(arg)
	-- arg[1] is download object
	-- arg[2] is selected beatmap track data
	beatmapList.push()
	self.persist.isCoverDownloading = false
	self.persist.isAudioDownloading = false
	self.persist.isBeatmapDownloading = false
	self.persist.gamestateEntering = false
	self.persist.download = arg[1]
	self.persist.trackData = arg[2]

	if self.data.coverArt == nil then
		local name = getLiveIconPath(self)
		if util.fileExists(name) then
			async.runFunction(function()
				-- TODO: Review a better option for this case
				self.data.coverArt = assetCache.loadImage(name, {mipmaps = true}, function(_, msg)
					love.filesystem.remove(name)
					log.error("download_beatmap", msg)
					self.data.coverArt = nil
					downloadCoverArt(self)
				end)
			end):run()
		else
			downloadCoverArt(self)
		end
	end

	-- Set title
	setTitle(self, self.persist.trackData.name)
	-- List difficulty
	async.runFunction(initializeDifficultyButton):run(self)
end

function beatmapInfoDL:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	-- Cannot draw gradient in vires
	love.graphics.push()
	love.graphics.origin()
	love.graphics.draw(self.data.gradient)
	love.graphics.pop()
	-- Okay the rest can be in vires
	love.graphics.draw(self.assets.images.titleBar, 170, 500)
	love.graphics.draw(self.data.titleText)
	love.graphics.draw(self.data.diffText)
	love.graphics.rectangle("fill", 295, 71, 370, 370, 3, 3)
	love.graphics.rectangle("line", 295, 71, 370, 370, 3, 3)
	if self.data.coverArt then
		local w, h = self.data.coverArt:getDimensions()
		love.graphics.draw(self.data.coverArt, 296, 72, 0, 368/w, 368/h)
	end
	love.graphics.draw(self.assets.images.goalInfo, 670, 70, 0, 8/9, 8/9)
	love.graphics.draw(self.data.goalsText)
	love.graphics.draw(self.data.statusText)
	love.graphics.draw(self.data.staticText)

	self.data.diffFrame:draw()
	glow.draw()
end

function beatmapInfoDL:exit()
	beatmapList.pop()
	self.persist.download:cancel()
end

function beatmapInfoDL:paused()
	self.persist.gamestateEntering = false
end

beatmapInfoDL:registerEvent("resize", function(self, w, h)
	self.data.gradient = createGradientMesh(w, h)
end)

beatmapInfoDL:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		leave()
	end
end)

return beatmapInfoDL
