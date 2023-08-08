-- Live result display
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local lsr = require("libs.lsr")
local CubicBezier = require("libs.cubic_bezier")

local MainFont = require("main_font")
local color = require("color")
local Setting = require("setting")
local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local Util = require("util")
local L = require("language")

local BackgroundLoader = require("game.background_loader")
local Glow = require("game.afterglow")
local CircleIconButton = require("game.ui.circle_icon_button")

local interpolation = CubicBezier(0.4, 0, 0.2, 1):getFunction()
local mipmaps = {mipmaps = true}
local accuracyColorMap = {
	{color.hexFF0AD8, "PERFECT"},
	{color.hexFF6854, "GREAT"},
	{color.hex1DBB1A, "GOOD"},
	{color.hex1CA0FF, "BAD"},
	{color.hexFF5C5C, "MISS"}
}
local rankingQuad

local resultScreen = Gamestate.create {
	fonts = {},
	images = {
		arrowBack = {"assets/image/ui/over_the_rainbow/arrow_back.png", mipmaps},
		coverMask = {"assets/image/ui/cover_mask.png", mipmaps},
		ranking = {"assets/image/ui/ranking.png", mipmaps},
		reload = {"assets/image/ui/over_the_rainbow/reload.png", mipmaps},
		save = {"assets/image/ui/over_the_rainbow/save.png", mipmaps},
		videocam = {"assets/image/ui/over_the_rainbow/videocam.png", mipmaps},
	}
}

local function showText(self, text)
	self.persist.statusText:clear()
	local length = self.data.mainFont:getWidth(text)
	self.persist.statusText:add({color.black, text}, 0, 0, 0, 18/32, 18/32, length * 0.5, 0)
	self.persist.statusTimer = 0
end

local function PV(v, i)
	return tostring(math.floor(v * i + 0.5))
end

local function leave()
	Gamestate.leave(LoadingInstance.getInstance())
end

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
	Glow.clear()

	rankingQuad = {
		love.graphics.newQuad(0, 2, 620, 150, 620, 604),
		love.graphics.newQuad(0, 152, 620, 150, 620, 604),
		love.graphics.newQuad(0, 302, 620, 150, 620, 604),
		love.graphics.newQuad(0, 452, 620, 150, 620, 604),
	}
	local saveAllowed = arg.allowSave and not(arg.autoplay)

	self.data.background = arg.background or BackgroundLoader.load(Setting.get("BACKGROUND_IMAGE"))

	if self.data.mainFont == nil then
		self.data.mainFont = MainFont.get(32)
	end

	if self.data.coverMaskShader == nil then
		self.data.coverMaskShader = love.graphics.newShader([[
			extern Image mask;
			vec4 effect(vec4 color, Image tex, vec2 tc, vec2 sc)
			{
				vec4 col1 = Texel(tex, tc);
				return color * vec4(col1.rgb, col1.a * Texel(mask, tc).r);
			}
		]])
		self.data.coverMaskShader:send("mask", self.assets.images.coverMask)
	end

	if self.data.back == nil then
		self.data.back = CircleIconButton(color.transparent, 36, self.assets.images.arrowBack, 0.32)
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 32, 4)

	do
		if not(arg.autoplay) and self.data.showReplay == nil then
			self.data.showReplay = CircleIconButton(color.hexFFDF35, 43, self.assets.images.videocam, 0.32)
			self.data.showReplay:addEventListener("mousereleased", function()
				Gamestate.replace(LoadingInstance.getInstance(), "livesim2", {
					summary = arg.summary,
					beatmapName = arg.name,
					replay = arg.replay,
					allowRetry = not(arg.allowRetry),
				})
			end)
		end

		if arg.allowRetry and self.data.reloadLive == nil then
			self.data.reloadLive = CircleIconButton(color.hex1CA0FF, 43, self.assets.images.reload, 0.32)
			self.data.reloadLive:addEventListener("mousereleased", function()
				-- It may contain replay data, but the table may used somewhere
				-- so clone it first.
				local newArg = {}
				for k, v in pairs(arg.livesim2) do
					newArg[k] = v
				end
				newArg.replay = nil

				return Gamestate.replace(LoadingInstance.getInstance(), "livesim2", newArg)
			end)
		end

		if saveAllowed and self.data.saveReplay == nil then
			self.data.saveReplay = CircleIconButton(color.hexFF4FAE, 43, self.assets.images.save, 0.32)
			self.data.saveReplay:addEventListener("mousereleased", function()
				local name
				if not(love.filesystem.createDirectory("replays/"..arg.name)) then
					showText(self, L"livesim2:replay:errorDirectory")
					return
				end

				if arg.replay.filename then
					showText(self, L"livesim2:replay:errorAlreadySaved")
					return
				end

				name = "replays/"..arg.name.."/"..arg.replay.timestamp..".lsr"
				if Util.fileExists(name) then
					showText(self, L"livesim2:replay:errorAlreadySaved")
					return
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
					showText(self, L"livesim2:replay:saved")
				else
					showText(self, L"livesim2:replay:errorSaveGeneric")
				end
			end)
		end

		local addX = 840
		if self.data.reloadLive then
			Glow.addFixedElement(self.data.reloadLive, addX, 176)
			addX = addX - 96
		end

		if self.data.showReplay then
			Glow.addFixedElement(self.data.showReplay, addX, 176)
			addX = addX - 96
		end

		if self.data.saveReplay then
			Glow.addFixedElement(self.data.saveReplay, addX, 176)
		end
	end
end

function resultScreen:start(arg)
	self.persist.nameText = love.graphics.newText(self.data.mainFont)
	self.persist.statusText = love.graphics.newText(self.data.mainFont)
	self.persist.indicatorText = love.graphics.newText(self.data.mainFont)
	self.persist.valueInfoText = love.graphics.newText(self.data.mainFont)
	self.persist.statusTimer = 0 -- show for 0.2 + 5 + 0.5 seconds
	self.persist.replay = arg.replay
	self.persist.comboRange = arg.comboRange or {
		math.ceil(arg.replay.totalNotes * 0.3),
		math.ceil(arg.replay.totalNotes * 0.5),
		math.ceil(arg.replay.totalNotes * 0.7),
		arg.replay.totalNotes
	}
	self.persist.scoreRange = arg.summary.scoreS and {
		arg.summary.scoreC,
		arg.summary.scoreB,
		arg.summary.scoreA,
		arg.summary.scoreS,
	}
	self.persist.comboWeight = arg.replay.perfect + arg.replay.great + arg.replay.good + arg.replay.bad + arg.replay.miss
	self.persist.coverArt = arg.summary.coverArt and arg.summary.coverArt.image
	if self.persist.coverArt then
		self.persist.coverArt = love.graphics.newImage(self.persist.coverArt, mipmaps)
	end

	self.persist.nameText:addf(arg.summary.name, 740, "left")

	do
		local combo = arg.replay.maxCombo

		if self.persist.scoreRange then
			local score = arg.replay.score
			if score >= self.persist.scoreRange[4] then
				self.persist.scoreQuad = rankingQuad[4]
			elseif score >= self.persist.scoreRange[3] then
				self.persist.scoreQuad = rankingQuad[3]
			elseif score >= self.persist.scoreRange[2] then
				self.persist.scoreQuad = rankingQuad[2]
			elseif score >= self.persist.scoreRange[1] then
				self.persist.scoreQuad = rankingQuad[1]
			end
		end

		if combo >= self.persist.comboRange[4] then
			self.persist.comboQuad = rankingQuad[4]
		elseif combo >= self.persist.comboRange[3] then
			self.persist.comboQuad = rankingQuad[3]
		elseif combo >= self.persist.comboRange[2] then
			self.persist.comboQuad = rankingQuad[2]
		elseif combo >= self.persist.comboRange[1] then
			self.persist.comboQuad = rankingQuad[1]
		end
	end

	do
		local accuracyData = arg.replay.accuracy
		local lines = {}
		self.persist.graphCanvas = Util.newCanvas(900, 132, nil, true)
		self.persist.graphTimer = 0 -- up to 3 seconds
		self.persist.graphShader = love.graphics.newShader([[
			extern number p;

			vec4 effect(vec4 color, Image tex, vec2 tc, vec2 _)
			{
				if (tc.x > p)
					discard;
				else
					return Texel(tex, tc) * color;
			}
		]])

		if #accuracyData == 0 then
			lines[1] = 5
			lines[2] = 132
			lines[3] = 894
			lines[4] = 132
		else
			for i = 1, 890 do
				local idx = (i-1) / 890 * #accuracyData
				local v0 = accuracyData[math.floor(idx)+1]
				local v1 = accuracyData[math.ceil(idx)+1] or accuracyData[#accuracyData]
				local t = idx % 1
				local v = (1 - t) * v0 + t * v1
				lines[#lines + 1] = i - 1 + 5
				lines[#lines + 1] = 132 - v * 127
			end
		end

		love.graphics.push("all")
		love.graphics.reset()
		love.graphics.setCanvas(self.persist.graphCanvas)
		love.graphics.clear(color.compat(255, 222, 45, 0))
		love.graphics.setColor(color.hexFFDE2D)
		love.graphics.setLineWidth(3)
		love.graphics.setLineJoin("bevel")
		love.graphics.line(lines)
		love.graphics.pop()
	end

	-- 274x368 start, step +120+0
	local fsc = 18/32
	for i, v in ipairs(accuracyColorMap) do
		self.persist.indicatorText:addf(v, 120 / fsc, "center", 274 - 60 + (i - 1) * 120, 406, 0, fsc)
	end
	self.persist.indicatorText:addf({color.black, "COMBO"}, 120 / fsc, "center", 274 - 60 + 5 * 120, 406, 0, fsc)
	self.persist.indicatorText:addf({color.black, "Score"}, 240 * 32/24, "center", 480, 260, 0, 24/32, 24/32, 120 * 32/24)
end

function resultScreen:update(dt)
	local needRefresh = self.persist.graphTimer < 3
	if needRefresh then
		self.persist.graphTimer = math.min(self.persist.graphTimer + dt, 3)
	end
	local interp = self.persist.graphTimer / 3
	local ip = interpolation(interp)

	if self.persist.statusTimer < 5.7 then
		self.persist.statusTimer = math.min(self.persist.statusTimer + dt, 5.7)
	end

	self.persist.graphShader:send("p", interp)

	if needRefresh then
		local info = self.persist.replay
		self.persist.valueInfoText:clear()

		-- 274x368 start, step +120+0
		for i, v in ipairs(accuracyColorMap) do
			local cv = info[v[2]:lower()]
			local combo = math.floor(cv * interp + 0.5)

			self.persist.valueInfoText:addf(
				{v[1], tostring(combo)},
				120, "center",
				274 - 60 + (i - 1) * 120, 360
			)
			self.persist.valueInfoText:addf(
				{v[1], string.format("%.2f%%", combo / self.persist.comboWeight * 100)},
				120 * 32/16, "center",
				-- 214 + 0 * 120
				274 - 60 + (i - 1) * 120, 392, 0, 16/32
			)
		end
		-- COMBO
		self.persist.valueInfoText:addf(
			{color.black, PV(info.maxCombo, ip)},
			120, "center",
			-- 214 + 5 * 120
			814, 360
		)
		-- Score
		self.persist.valueInfoText:addf({color.black, PV(info.score, ip)}, 360, "center", 300, 296)
	end
end

function resultScreen:draw()
	-- Draw background
	local shader = love.graphics.getShader()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.setColor(color.hex646262AA)
	love.graphics.rectangle("fill", -88, -43, 1136, 280)
	love.graphics.setColor(color.white)

	if self.persist.coverArt then
		local w, h = self.persist.coverArt:getDimensions()
		love.graphics.setShader(self.data.coverMaskShader)
		love.graphics.draw(self.persist.coverArt, 63, 84, 0, 130 / w, 130 / h)
		love.graphics.setShader(shader)
	else
		love.graphics.setColor(color.hexFF9486)
		love.graphics.rectangle("fill", 63, 84, 130, 130)
		love.graphics.rectangle("line", 63, 84, 130, 130)
		love.graphics.setColor(color.white)
	end

	love.graphics.rectangle("fill", -88, 231, 1136, 452)
	love.graphics.setShader(Util.drawText.workaroundShader)
	love.graphics.draw(self.persist.nameText, 214, 100)
	local c = love.graphics.getCanvas()
	love.graphics.draw(self.persist.indicatorText)
	love.graphics.draw(self.persist.valueInfoText)
	local statusOpacity =
		self.persist.statusTimer < 0.2 and (self.persist.statusTimer * 5) or
		(self.persist.statusTimer >= 5.2 and (1 - (self.persist.statusTimer - 5.2) * 2) or 1)
	love.graphics.setColor(color.compat(255, 255, 255, statusOpacity))
	love.graphics.draw(self.persist.statusText, 480, 446)
	love.graphics.setColor(color.white)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.setShader(self.persist.graphShader)
	love.graphics.draw(self.persist.graphCanvas, 30, 493)
	love.graphics.setBlendMode("alpha", "alphamultiply")
	love.graphics.setCanvas(c)
	love.graphics.setShader(shader)

	if self.persist.graphTimer >= 2.8 then
		local ip3 = interpolation((self.persist.graphTimer - 2.8) * 5)
		love.graphics.setColor(color.compat(255, 255, 255, ip3))

		if self.persist.scoreQuad then
			love.graphics.draw(self.assets.images.ranking, self.persist.scoreQuad, 32, 268, 0, 0.24)
		end

		if self.persist.comboQuad then
			love.graphics.draw(self.assets.images.ranking, self.persist.comboQuad, 32, 372, 0, 0.24)
		end
	end

	return Glow.draw()
end

resultScreen:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return resultScreen
