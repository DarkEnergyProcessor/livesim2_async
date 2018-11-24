-- Beatmap Downloader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local JSON = require("libs.JSON")
local ls2 = require("libs.ls2")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local color = require("color")
local mainFont = require("font")
local util = require("util")
local md5 = require("game.md5")
local L = require("language")

local glow = require("game.afterglow")
local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local selectButton = require("game.ui.select_button")
local checkbox = require("game.ui.checkbox")

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

	if fmt then
		local str = string.format(fmt, ...)
		util.addTextWithShadow(self.data.statusText, str, 52, 590)
		self.persist.statusText = str
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
	self.data.titleText:addf({color.black, text}, 719, "center", 172, 575)
	self.data.titleText:addf({color.white, text}, 719, "center", 170, 574)
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

local function getHashedName(str)
	local keyhash = md5("The quick brown fox jumps over the lazy dog"..str)
	local filehash = md5(str)
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

local function getLS2Name(difficulty)
	local hashedname = DLBeatmap.GetHashedName(DLBeatmap.TrackData.live[difficulty].livejson)
	return "beatmap/"..hashedname:sub(1, -#DLBeatmap.TrackData.live[difficulty].livejson - 1)..".sif."..difficulty..".ls2"
end

local function leave()
	return gamestate.leave(nil)
end

function beatmapInfoDL:load()
	glow.clear()
	local font22 = mainFont.get(22)

	if self.data.titleText == nil then
		self.data.titleText = love.graphics.newText(mainFont.get(36))
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
	self.data.diffFrame:clear()
	glow.addFrame(self.data.diffFrame)

	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
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

	if self.data.statusText == nil then
		self.data.statusText = love.graphics.newText(font22)
		if self.persist.statusText then
			util.addTextWithShadow(self.data.statusText, self.persist.statusText, 296, 460)
		end
	end
end

function beatmapInfoDL:start(arg)
	-- arg[1] is download object
	-- arg[2] is selected beatmap track data
	self.persist.download = arg[1]
	self.persist.beatmapTrackData = arg[2]

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

	self.data.diffFrame:draw()
	glow.draw()
end

function beatmapInfoDL:exit()
	self.persist.download:cancel()
end

beatmapInfoDL:registerEvent("resize", function(self, w, h)
	self.data.gradient = createGradientMesh(w, h)
end)

beatmapInfoDL:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		leave()
	end
end)
