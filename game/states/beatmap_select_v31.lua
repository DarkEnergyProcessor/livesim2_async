-- Beatmap selection (v3.1)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local async = require("async")
local color = require("color")
local mainFont = require("font")
local setting = require("setting")
local fileDialog = require("file_dialog")
local util = require("util")
local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")
local L = require("language")

local beatmapList = require("game.beatmap.list")
local glow = require("game.afterglow")
local ripple = require("game.ui.ripple")
local ciButton = require("game.ui.circle_icon_button")

local mipmaps = {mipmaps = true}
local beatmapSelect = gamestate.create {
	images = {
		coverMask = {"assets/image/ui/cover_mask.png", mipmaps},
		downloadCircle = {"assets/image/ui/over_the_rainbow/download_beatmap.png", mipmaps},
		dropDown = {"assets/image/ui/over_the_rainbow/expand.png", mipmaps},
		fastForward = {"assets/image/ui/over_the_rainbow/fast_forward.png", mipmaps},
		movie = {"assets/image/ui/over_the_rainbow/movie.png", mipmaps},
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmaps},
		play = {"assets/image/ui/over_the_rainbow/play.png", mipmaps},
		shuffle = {"assets/image/ui/over_the_rainbow/shuffle.png", mipmaps},
		star = {"assets/image/ui/over_the_rainbow/star.png", mipmaps},
		video = {"assets/image/ui/over_the_rainbow/video.png", mipmaps},
	},
	fonts = {
		formatFont = {"fonts/Roboto-Regular.ttf", 15}
	},
}

-- One shot usage, no need to have it in different file
-- 451x94
local beatmapSelectButton = Luaoop.class("Livesim2.BeatmapSelect.BeatmapSelectButton", glow.element)
local optionToggleButton = Luaoop.class("Livesim2.BeatmapSelect.OptionToggleButton", glow.element)

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

	function beatmapSelectButton:new(state, name, format, coverImage)
		coverShader = coverShader or state.data.coverMaskShader

		self.name = love.graphics.newText(state.data.titleFont, name)
		self.format = love.graphics.newText(state.assets.fonts.formatFont, format)
		self:setCoverImage(coverImage)

		self.width, self.height = 450, 94
		self.x, self.y = 0, 0
		self.ripple = ripple(460.691871)
		self.selected = false
		self.stencilFunc = function()
			love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		end
		self.isPressed = false
		self:addEventListener("mousepressed", commonPressed)
		self:addEventListener("mousereleased", commonReleased)
		self:addEventListener("mousecanceled", commonReleased)
	end

	function beatmapSelectButton:setCoverImage(coverImage)
		if coverImage then
			local w, h = coverImage:getDimensions()
			self.coverScaleW, self.coverScaleH = 82 / w, 82 / h
		end

		self.coverImage = coverImage
	end

	function beatmapSelectButton:update(dt)
		self.ripple:update(dt)
	end

	function beatmapSelectButton:render(x, y)
		local shader = love.graphics.getShader()
		self.x, self.y = x, y

		love.graphics.setColor(self.selected and color.hexFF4FAE or color.hex434242)
		love.graphics.rectangle("fill", x, y, self.width, self.height)
		love.graphics.setShader(util.drawText.workaroundShader)
		love.graphics.setColor(color.white)
		love.graphics.draw(self.name, x + 110, y + 20)
		love.graphics.draw(self.format, x + 110, y + 60)

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
			love.graphics.stencil(self.stencilFunc, "replace", 1, false)
			love.graphics.setStencilTest("equal", 1)
			self.ripple:draw(255, 255, 255, x, y)
			love.graphics.setStencilTest()
		end
	end

	function optionToggleButton:new(checked, image, imageS, imageY, font, text, textY)
		self.image = image
		self.imageW, self.imageH = image:getDimensions()
		self.imageS = imageS
		self.imageY = imageY
		self.description = love.graphics.newText(font)
		self.descriptionY = textY
		self.description:add(text, font:getWidth(text) * -0.5, 0)

		self.width, self.height = 120, 98
		self.x, self.y = 0, 0
		self.ripple = ripple(154.932243)
		self.selected = false
		self.stencilFunc = function()
			love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		end
		self.isPressed = false
		self.checked = not(not(checked))
		self:addEventListener("mousepressed", commonPressed)
		self:addEventListener("mousereleased", optionToggleButton._released)
		self:addEventListener("mousecanceled", commonReleased)
	end

	function optionToggleButton:_released()
		commonReleased(self)
		self.checked = not(self.checked)
		self:triggerEvent("changed", self.checked)
	end

	function optionToggleButton:update(dt)
		self.ripple:update(dt)
	end

	function optionToggleButton:render(x, y)
		self.x, self.y = x, y

		love.graphics.setColor(color.hexEF46A1)
		love.graphics.rectangle("fill", x, y, self.width, self.height)
		love.graphics.setColor(self.checked and color.white or color.black)
		love.graphics.draw(
			self.image, x + 60, y + self.imageY, 0,
			self.imageS, self.imageS,
			self.imageW * 0.5, self.imageH * 0.5
		)
		util.drawText(self.description, x + 60, y + self.descriptionY)

		if self.ripple:isActive() then
			love.graphics.stencil(self.stencilFunc, "replace", 1, false)
			love.graphics.setStencilTest("equal", 1)
			self.ripple:draw(255, 255, 255, x, y)
			love.graphics.setStencilTest()
		end
	end
end

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

local function setStatusText(self, text, blink)
	self.persist.statusText:clear()
	if not(text) or #text == 0 then return end

	local x = self.persist.beatmapText:getWidth() + 54
	self.persist.statusText:add(text, x, 106)
	self.persist.statusTextBlink = blink and 0 or math.huge
end

local function createOptionToggleSetting(settingName, image, imageS, imageY, font, text, textY)
	local x = optionToggleButton(setting.get(settingName) == 1, image, imageS, imageY, font, text, textY)
	x:addEventListener("changed", function(_, _, value)
		setting.set(settingName, value and 1 or 0)
	end)
	return x
end

function beatmapSelect:load()
	glow.clear()

	do
		local a, b, c, d, e = mainFont.get(23, 24, 16, 44, 9)
		self.data.statusFont = a
		self.data.titleFont = b
		self.data.optionDetailFont = c
		self.data.beatmapTitleFont = d
		self.data.infoFont = e
	end

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = util.gradient("vertical", color.black75PT, color.transparent)
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
		self.data.back = ciButton(color.hex333131, 36, self.assets.images.navigateBack, 0.24, color.hexFF4FAE)
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", leave)
	end
	glow.addFixedElement(self.data.back, 32, 4)

	if self.data.downloadBeatmap == nil then
		self.data.downloadBeatmap = ciButton(color.hex333131, 36, self.assets.images.downloadCircle, 0.32, color.hexFF4FAE)
		self.data.downloadBeatmap:addEventListener("mousereleased", function()
			gamestate.enter(loadingInstance.getInstance(), "beatmapDownload")
		end)
		self.data.downloadBeatmap:setData(self)
	end
	glow.addFixedElement(self.data.downloadBeatmap, 856, 4)

	-- Option toggle
	if self.data.autoplayToggle == nil then
		self.data.autoplayToggle = createOptionToggleSetting(
			"AUTOPLAY",
			self.assets.images.fastForward, 0.16, 44,
			self.data.optionDetailFont, L"beatmapSelect:optionAutoplay", 60
		)
	end
	glow.addFixedElement(self.data.autoplayToggle, 480, 248)

	if self.data.randomToggle == nil then
		self.data.randomToggle = optionToggleButton(
			false,
			self.assets.images.fastForward, 0.16, 44,
			self.data.optionDetailFont, L"beatmapSelect:optionRandom", 60
		)
	end
	glow.addFixedElement(self.data.randomToggle, 600, 248)

	if self.data.storyToggle == nil then
		self.data.storyToggle = createOptionToggleSetting(
			"STORYBOARD",
			self.assets.images.video, 0.16, 44,
			self.data.optionDetailFont, L"beatmapSelect:optionStoryboard", 60
		)
	end
	glow.addFixedElement(self.data.storyToggle, 720, 248)

	if self.data.videoToggle == nil then
		self.data.videoToggle = createOptionToggleSetting(
			"VIDEOBG",
			self.assets.images.movie, 0.16, 44,
			self.data.optionDetailFont, L"beatmapSelect:optionVideo", 60
		)
	end
	glow.addFixedElement(self.data.videoToggle, 840, 248)
end

function beatmapSelect:start()
	self.persist.beatmapFrame = glow.frame(0, 152, 480, 488)
	self.persist.beatmaps = {sorted = false}
	self.persist.selectedBeatmap = nil
	self.persist.active = true
	self.persist.beatmapFrame:setVerticalSliderPosition("left")
	self.persist.beatmapFrame:setSliderColor(color.hex434242)
	self.persist.beatmapText = love.graphics.newText(self.data.beatmapTitleFont, L"beatmapSelect:beatmaps")
	self.persist.statusText = love.graphics.newText(self.data.statusFont)
	self.persist.statusTextBlink = math.huge

	local function beatmapSelected(_, data)
		for i, v in ipairs(data[1]) do
			v.element.selected = i == data[2]
		end

		self.persist.selectedBeatmap = data[2]
	end

	beatmapList.push()
	-- TODO: Categorize beatmaps based on their difficulty
	beatmapList.enumerate(function(id, name, fmt, diff)
		if id == "" then
			-- sort
			table.sort(self.persist.beatmaps, function(a, b)
				if a.name == b.name then
					return (a.difficulty or "") < (b.difficulty or "")
				else
					return a.name < b.name
				end
			end)

			for i, v in ipairs(self.persist.beatmaps) do
				beatmapList.getSummary(v.id, function(data)
					local imageCover = nil

					if data.coverArt then
						local image = love.graphics.newImage(data.coverArt.image, mipmaps)
						local w, h = image:getDimensions()
						v.coverArtImage = image

						if w > 256 or h > 256 then
							imageCover = util.newCanvas(256, 256)
							love.graphics.push("all")
							love.graphics.reset()
							love.graphics.setCanvas(imageCover)
							love.graphics.setColor(color.white)
							love.graphics.setBlendMode("alpha", "premultiplied")
							love.graphics.draw(image, 0, 0, 0, 256 / w, 256 / h)
							love.graphics.pop()
						else
							imageCover = image
						end
					end

					v.summary = data
					v.element:setCoverImage(imageCover)
					v.element:addEventListener("mousereleased", beatmapSelected)
				end)

				v.element:setData({self.persist.beatmaps, i})
				self.persist.beatmapFrame:addElement(v.element, 30, (i - 1) * 94)
			end

			self.persist.beatmaps.sorted = true

			if self.persist.active then
				setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}), false)
			end

			return false
		end

		self.persist.beatmaps[#self.persist.beatmaps + 1] = {
			id = id,
			name = name,
			format = fmt,
			difficulty = diff,
			element = beatmapSelectButton(self, name, fmt)
		}
		return true
	end)

	glow.addFrame(self.persist.beatmapFrame)
	setStatusText(self, L"beatmapSelect:loading", true)
end

function beatmapSelect:exit()
	self.persist.active = false
	beatmapList.pop(true)
end

function beatmapSelect:resumed()
	self.persist.active = true
	if self.persist.beatmaps.sorted then
		setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}), false)
	end
	glow.addFrame(self.persist.beatmapFrame)
end

function beatmapSelect:paused()
	self.persist.active = false
end

function beatmapSelect:update(dt)
	self.persist.beatmapFrame:update(dt)

	if self.persist.statusTextBlink ~= math.huge then
		self.persist.statusTextBlink = (self.persist.statusTextBlink + dt) % 2
	end
end

function beatmapSelect:draw()
	love.graphics.setColor(color.hex434242)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	love.graphics.setColor(color.hexFF4FAE)
	love.graphics.rectangle("fill", 480, 10, 480, 336)

	local shader = love.graphics.getShader()
	love.graphics.setShader(util.drawText.workaroundShader)
	love.graphics.setColor(color.white)
	love.graphics.draw(self.persist.beatmapText, 30, 93)
	if self.persist.statusTextBlink ~= math.huge then
		love.graphics.setColor(color.compat(255, 255, 255, math.abs(1 - self.persist.statusTextBlink)))
	end
	love.graphics.draw(self.persist.statusText)
	love.graphics.setColor(color.white)

	if self.persist.selectedBeatmap then
		local v = self.persist.beatmaps[self.persist.selectedBeatmap]
		love.graphics.setFont(self.data.titleFont)
		love.graphics.printf(v.name, 500, 98, 280)

		if v.summary.coverArt and v.summary.coverArt.info then
			love.graphics.setFont(self.data.infoFont)
			love.graphics.printf(v.summary.coverArt.info, 500, 176, 280)
		end

		if v.coverArtImage then
			local w, h = v.coverArtImage:getDimensions()
			love.graphics.setShader(self.data.coverMaskShader)
			love.graphics.draw(v.coverArtImage, 786, 94, 0, 140 / w, 140 / h)
		else
			love.graphics.setColor(color.hexC4C4C4)
			love.graphics.rectangle("fill", 786, 94, 140, 140, 15, 15)
			love.graphics.rectangle("line", 786, 94, 140, 140, 15, 15)
			love.graphics.setColor(color.white)
		end
	else
		love.graphics.setColor(color.hexC4C4C4)
		love.graphics.rectangle("fill", 786, 94, 140, 140, 15, 15)
		love.graphics.rectangle("line", 786, 94, 140, 140, 15, 15)
		love.graphics.setColor(color.white)
	end

	love.graphics.setShader(shader)
	love.graphics.rectangle("fill", 480, 346, 480, 294)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(color.hex333131)
	love.graphics.rectangle("fill", -88, 0, 1136, 80)

	glow.draw()
	self.persist.beatmapFrame:draw()
end

return beatmapSelect
