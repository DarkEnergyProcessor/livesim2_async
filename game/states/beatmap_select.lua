-- Beatmap selection
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local lsr = require("libs.lsr")

local color = require("color")
local MainFont = require("main_font")
local Setting = require("setting")
local fileDialog = require("file_dialog")
local log = require("logging")
local Util = require("util")
local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local L = require("language")

local BeatmapList = require("game.beatmap.list")
local ColorTheme = require("game.color_theme")
local Glow = require("game.afterglow")
local Ripple = require("game.ui.ripple")
local CircleIconButton = require("game.ui.circle_icon_button")

local mipmaps = {mipmaps = true}

-- One shot usage, no need to have it in different file
-- 451x94
local beatmapSelectButton = Luaoop.class("Livesim2.BeatmapSelect.BeatmapSelectButton", Glow.Element)
local optionToggleButton = Luaoop.class("Livesim2.BeatmapSelect.OptionToggleButton", Glow.Element)
local playButton = Luaoop.class("Livesim2.BeatmapSelect.PlayButton", Glow.Element)
local diffDropdown = Luaoop.class("Livesim2.BeatmapSelect.DifficultyDropdown", Glow.Element)
local diffText = Luaoop.class("Livesim2.BeatmapSelect.DifficultySelect", Glow.Element)
local replayButton = Luaoop.class("Livesim2.BeatmapSelect.ReplayButton", Glow.Element)

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

		self.name = love.graphics.newText(state.data.mainFont)
		self.name:add(name, 0, 0, 0, 24/44)
		self.format = love.graphics.newText(state.assets.fonts.formatFont, format)
		self:setCoverImage(coverImage)

		self.width, self.height = 450, 94
		self.x, self.y = 0, 0
		self.ripple = Ripple(460.691871)
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

		love.graphics.setColor(self.selected and ColorTheme.get() or color.hex434242)
		love.graphics.rectangle("fill", x, y, self.width, self.height)
		love.graphics.setShader(Util.drawText.workaroundShader)
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
			Util.stencil11(self.stencilFunc, "replace", 1, false)
			Util.setStencilTest11("equal", 1)
			self.ripple:draw(255, 255, 255, x, y)
			Util.setStencilTest11()
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
		self.ripple = Ripple(154.932243)
		self.selected = false
		self.stencilFunc = function()
			love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		end
		self.isPressed = false
		self.checked = not(not(checked))
		self.blurIcon = Util.drawBlur(120, 98, 2, optionToggleButton._renderIcon, self, color.white, 0, 0)
		self:addEventListener("mousepressed", commonPressed)
		self:addEventListener("mousereleased", optionToggleButton._released)
		self:addEventListener("mousecanceled", commonReleased)
	end

	function optionToggleButton:_released()
		commonReleased(self)
		self.checked = not(self.checked)
		self:triggerEvent("changed", self.checked)
	end

	function optionToggleButton:_renderIcon(col, x, y)
		if col then love.graphics.setColor(col) end

		love.graphics.draw(
			self.image, x + 60, y + self.imageY, 0,
			self.imageS, self.imageS,
			self.imageW * 0.5, self.imageH * 0.5
		)
		Util.drawText(self.description, x + 60, y + self.descriptionY)
	end

	function optionToggleButton:update(dt)
		self.ripple:update(dt)
	end

	function optionToggleButton:render(x, y)
		self.x, self.y = x, y

		love.graphics.setColor(ColorTheme.getDark())
		love.graphics.rectangle("fill", x, y, self.width, self.height)

		if self.checked then
			love.graphics.setColor(color.white)
			love.graphics.setBlendMode("alpha", "premultiplied")
			love.graphics.draw(self.blurIcon, x, y)
			love.graphics.setBlendMode("alpha", "alphamultiply")
			self:_renderIcon(nil, x, y)
		else
			self:_renderIcon(color.black, x, y)
		end

		if self.ripple:isActive() then
			Util.stencil11(self.stencilFunc, "replace", 1, false)
			Util.setStencilTest11("equal", 1)
			self.ripple:draw(255, 255, 255, x, y)
			Util.setStencilTest11()
		end
	end

	function playButton:new(font, pb)
		local text = L"beatmapSelect:play"
		self.text = love.graphics.newText(font)
		self.text:add(text, 0, 0, 0, 15/16)
		self.image = pb

		self.height = 40
		self.width = math.ceil(pb:getWidth() * 0.24 + font:getWidth(text) * 15/16 + 40)
		self.x, self.y = 0, 0
		self.ripple = Ripple(math.sqrt(self.width * self.width + 1600))
		self.selected = false
		self.stencilFunc = function()
			love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 20, 20)
		end
		self.isPressed = false
		self:addEventListener("mousepressed", playButton._pressed)
		self:addEventListener("mousereleased", commonReleased)
		self:addEventListener("mousecanceled", commonReleased)
	end

	function playButton:_pressed(_, x, y)
		if
			-- Square
			(x >= 20 and y >= 0 and x < self.width - 20 and y < 40) or
			-- Circle left
			Util.distance(x, y, 20, 20) <= 20 or
			-- Circle right
			Util.distance(x, y, self.width - 20, 20) <= 20
		then
			self.isPressed = true
			self.ripple:pressed(x, y)
			return false
		else
			return true
		end
	end

	function playButton:update(dt)
		self.ripple:update(dt)
	end

	function playButton:render(x, y)
		self.x, self.y = x, y
		love.graphics.setColor(color.hexFFDF35)
		love.graphics.rectangle("fill", x, y, self.width, self.height, 20, 20)
		love.graphics.rectangle("line", x, y, self.width, self.height, 20, 20)
		love.graphics.setColor(color.white)
		love.graphics.draw(self.image, x + 12, y + 7, 0, 0.32)
		Util.drawText(self.text, x + 37, y + 12)

		if self.ripple:isActive() then
			Util.stencil11(self.stencilFunc, "replace", 1, false)
			Util.setStencilTest11("equal", 1)
			self.ripple:draw(255, 255, 255, x, y)
			Util.setStencilTest11()
		end
	end

	local cb = require("libs.cubic_bezier")
	local dropdownInterpolation = cb(0.4, 0, 0.2, 1):getFunction()

	-- This one is not meant to be "glow.addElement" directly.
	-- font = mainFont2
	function diffDropdown:new(font)
		self.optionText = love.graphics.newText(font)
		self.optionUpdated = true
		self.timer = 0
		self.width, self.height = 150, 0
		self.realHeight = 26
		self.items = {}
		self.destFrame = nil
		self.x, self.y = 0, 0

		self:addEventListener("mousepressed", diffDropdown._pressed)
		self:addEventListener("mousemoved", diffDropdown._moved)
		self:addEventListener("mousereleased", diffDropdown._released)
		self:addEventListener("mousecanceled", diffDropdown.hide)
	end

	function diffDropdown:_pressed(_, x, y)
		self.x, self.y = x, y
	end

	function diffDropdown:_moved(_, x, y)
		self.x, self.y = x, y
	end

	function diffDropdown:_released()
		local clickedIndex = math.floor(self.y / 26) + 1
		if self.items[clickedIndex] then
			self:triggerEvent("itemselected", clickedIndex, self.items[clickedIndex])
		end

		self:hide()
	end

	function diffDropdown:_updateList()
		if not(self.optionUpdated) then
			self.optionText:clear()
			self.realHeight = #self.items * 26

			for i, v in ipairs(self.items) do
				self.optionText:add(tostring(v), 18, (i - 1) * 26 + 4)
			end

			self.optionUpdated = true
		end
	end

	function diffDropdown:setItems(items)
		self.items = {}
		for i = 1, #items do
			self.items[i] = items[i]
		end

		self.optionUpdated = false
	end

	function diffDropdown:show(frame, x, y)
		if #self.items == 0 then
			error("attempt to show empty dropdown")
		end

		if self.destFrame then return end

		self.timer = 0
		self.destFrame = frame
		self:_updateList()
		frame:addElement(self, x, y)
	end

	function diffDropdown:isShown()
		return not(not(self.destFrame))
	end

	function diffDropdown:hide()
		local frame = self.destFrame
		self.timer = 0

		if frame then
			-- Prevent stack overflow
			self.destFrame = nil
			frame:removeElement(self)
		end
	end

	function diffDropdown:update(dt)
		self.timer = math.min(self.timer + dt * 5, 1)
		self:_updateList()
		self.height = dropdownInterpolation(self.timer) * self.realHeight
	end

	function diffDropdown:render(x, y)
		local maxloop = math.ceil(self.height / 26)

		love.graphics.setColor(color.hex434242)
		love.graphics.rectangle("fill", x, y, self.width, self.height)
		love.graphics.setColor(color.white75PT)
		for i = 1, maxloop do
			love.graphics.rectangle("line", x, y + (i - 1) * 26, 150, 26)
		end
		love.graphics.setColor(color.white)
		Util.drawText(self.optionText, x, y)
	end

	function diffText:new(font, img)
		self.text = love.graphics.newText(font)
		self.image = img -- "dropDown" image
		self.showImage = false
		self.width, self.height = 150, 26
	end

	function diffText:setText(text, showlist)
		self.text:clear()
		self.text:add(tostring(text or L"beatmapSelect:diffUnknown"))
		self.showImage = not(not(showlist))
	end

	function diffText:render(x, y)
		love.graphics.setColor(ColorTheme.getDarker())
		love.graphics.rectangle("fill", x, y, 150, 26, 13, 13)
		love.graphics.rectangle("line", x, y, 150, 26, 13, 13)
		love.graphics.setColor(color.white)
		Util.drawText(self.text, x + 18, y + 4)
		if self.showImage then
			love.graphics.draw(self.image, x + 120, y + 2, 0, 0.32)
		end
	end

	function replayButton:new(state, replay)
		local time = os.date("*t", replay.timestamp)
		self.name = love.graphics.newText(state.data.mainFont2)
		self.score = love.graphics.newText(state.data.mainFont2)
		self.name:add(L("general:dateFormat", {
			month = state.data.monthNames[time.month],
			day = time.day,
			year = time.year
		})..string.format(" %02d:%02d:%02d", time.hour, time.min, time.sec))
		self.score:addf(tostring(replay.score), 440, "right")

		self.width, self.height = 450, 72
		self.x, self.y = 0, 0
		self.ripple = Ripple(455.7236004422)
		self.stencilFunc = function()
			love.graphics.rectangle("fill", self.x, self.y, self.width, self.height)
		end
		self.isPressed = false
		self:addEventListener("mousepressed", commonPressed)
		self:addEventListener("mousereleased", commonReleased)
		self:addEventListener("mousecanceled", commonReleased)
	end

	function replayButton:update(dt)
		self.ripple:update(dt)
	end

	function replayButton:render(x, y)
		local shader = love.graphics.getShader()
		self.x, self.y = x, y

		love.graphics.rectangle("fill", x, y, self.width, self.height)
		love.graphics.setShader(Util.drawText.workaroundShader)
		love.graphics.setColor(color.black)
		love.graphics.draw(self.name, x + 16, y + 28)
		love.graphics.setColor(ColorTheme.get())
		love.graphics.draw(self.score, x, y + 28)
		love.graphics.setColor(color.white)
		love.graphics.setShader(shader)

		if self.ripple:isActive() then
			Util.stencil11(self.stencilFunc, "replace", 1, false)
			Util.setStencilTest11("equal", 1)
			self.ripple:draw(255, 79, 174, x, y)
			Util.setStencilTest11()
		end
	end
end

local function leave()
	return Gamestate.leave(LoadingInstance.getInstance())
end

local function setStatusText(self, text, blink)
	self.persist.statusText:clear()
	if not(text) or #text == 0 then return end

	local x = self.persist.beatmapText:getWidth() + 54
	self.persist.statusText:add(text, x, 106, 0, 23/44)
	self.persist.statusTextBlink = blink and 0 or math.huge
end

local function createOptionToggleSetting(settingName, image, imageS, imageY, font, text, textY)
	local x = optionToggleButton(Setting.get(settingName) == 1, image, imageS, imageY, font, text, textY)
	x:addEventListener("changed", function(_, _, value)
		Setting.set(settingName, value and 1 or 0)
	end)
	return x
end

local function startPlayBeatmap(_, self)
	if self.persist.selectedBeatmap and self.persist.beatmapSummary then
		local target = self.persist.beatmaps[self.persist.selectedBeatmap]

		if target.group then
			target = target.beatmaps[target.selected]
		end

		Gamestate.enter(LoadingInstance.getInstance(), "livesim2", {
			summary = self.persist.beatmapSummary,
			beatmapName = target.id,
			random = self.data.randomToggle.checked,
			storyboard = self.data.storyToggle.checked,
			videoBackground = self.data.videoToggle.checked
		})
	end
end

local function resizeImage(img, w, h)
	local canvas = Util.newCanvas(w, h, nil, true)
	local iw, ih = img:getDimensions()
	love.graphics.push("all")
	love.graphics.reset()
	love.graphics.setCanvas(canvas)
	love.graphics.setColor(color.white)
	love.graphics.setBlendMode("alpha", "premultiplied")
	love.graphics.draw(img, 0, 0, 0, w / iw, h / ih)
	love.graphics.pop()
	return canvas
end

local function enumerateReplays(id, hash)
	id = id:gsub(":", "__") -- multiple beatmap support
	local dest = {}

	if not(love.filesystem.createDirectory("replays/"..id)) then
		log.errorf("beatmapSelect", "failed to create directory 'replays/%s'", id)
	else
		for _, v in ipairs(love.filesystem.getDirectoryItems("replays/"..id.."/")) do
			if v:sub(-4) == ".lsr" then
				local replay, s = lsr.loadReplay("replays/"..id.."/"..v, hash)
				if replay then
					dest[#dest + 1] = replay
				else
					log.errorf("beatmapSelect", "failed to load replay %s: %s", v, s)
				end
			end
		end
	end

	table.sort(dest, function(a, b) return a.timestamp > b.timestamp end)
	return dest
end

local function updateBeatmapList(self)
	self.persist.beatmapFrame:clear()
	self.data.searchText:clear()

	if #self.persist.searchQuery > 0 then
		local i = 1
		local query = table.concat(self.persist.searchQuery)
		local queryLower = query:lower()

		for _, v in ipairs(self.persist.beatmaps) do
			if v.name:lower():find(queryLower, 1, true) then
				self.persist.beatmapFrame:addElement(v.element, 30, (i - 1) * 94)
				i = i + 1
			end
		end

		self.data.searchText:add(query, 0, 0, 0, 22/44)
		setStatusText(self, L("beatmapSelect:searchResult", {amount = i - 1}))
	else
		for i, v in ipairs(self.persist.beatmaps) do
			self.persist.beatmapFrame:addElement(v.element, 30, (i - 1) * 94)
		end

		self.data.searchText:add(L"beatmapSelect:searchPrompt", 0, 0, 0, 22/44)
		setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}))
	end
end

local beatmapSelect = Gamestate.create {
	images = {
		add = {"assets/image/ui/over_the_rainbow/add_icon.png", mipmaps},
		coverMask = {"assets/image/ui/cover_mask.png", mipmaps},
		delete = {"assets/image/ui/over_the_rainbow/delete.png", mipmaps},
		downloadCircle = {"assets/image/ui/over_the_rainbow/download_beatmap.png", mipmaps},
		dropDown = {"assets/image/ui/over_the_rainbow/expand.png", mipmaps},
		fastForward = {"assets/image/ui/over_the_rainbow/fast_forward.png", mipmaps},
		folder = {"assets/image/ui/over_the_rainbow/folder.png", mipmaps},
		movie = {"assets/image/ui/over_the_rainbow/movie.png", mipmaps},
		navigateBack = {"assets/image/ui/over_the_rainbow/navigate_back.png", mipmaps},
		play = {"assets/image/ui/over_the_rainbow/play.png", mipmaps},
		poll = {"assets/image/ui/over_the_rainbow/poll.png", mipmaps},
		search = {"assets/image/ui/over_the_rainbow/search.png", mipmaps},
		shuffle = {"assets/image/ui/over_the_rainbow/shuffle.png", mipmaps},
		star = {"assets/image/ui/over_the_rainbow/star.png", mipmaps},
		video = {"assets/image/ui/over_the_rainbow/video.png", mipmaps},
	},
	fonts = {
		formatFont = {"fonts/Roboto-Regular.ttf", 15}
	},
}

function beatmapSelect:load()
	Glow.clear()

	---@type Font
	self.data.mainFont, self.data.mainFont2 = MainFont.get(44, 16)

	if self.data.shadowGradient == nil then
		self.data.shadowGradient = Util.gradient("vertical", color.black75PT, color.transparent)
	end

	if self.data.coverMaskShader == nil then
		self.data.coverMaskShader = love.graphics.newShader("assets/shader/mask.fs")
		self.data.coverMaskShader:send("mask", self.assets.images.coverMask)
	end

	if self.data.replaysText == nil then
		self.data.replaysText = love.graphics.newText(self.data.mainFont2, L"beatmapSelect:replays")
	end

	if self.data.monthNames == nil then
		local t = {}

		for w in L("general:months"):gmatch("%S+") do
			t[#t + 1] = w
		end

		self.data.monthNames = t
	end

	if self.data.emptyReplaysText == nil then
		local t = love.graphics.newText(self.data.mainFont2)
		local l = L"beatmapSelect:noReplays"
		t:add(l, -0.5 * self.data.mainFont2:getWidth(l), 0)
		self.data.emptyReplaysText = t
	end

	if self.data.back == nil then
		self.data.back = CircleIconButton(color.hex333131, 36, self.assets.images.navigateBack, 0.48, ColorTheme.get())
		self.data.back:setData(self)
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 32, 4)

	if self.data.search == nil then
		self.data.search = CircleIconButton(color.hex333131, 36, self.assets.images.search, 0.64, ColorTheme.get())
		self.data.search:setData(self)
		self.data.search:addEventListener("mousereleased", function()
			love.keyboard.setTextInput(not(love.keyboard.hasTextInput()))
		end)
	end
	Glow.addFixedElement(self.data.search, 112, 4)

	if self.data.searchText == nil then
		self.data.searchText = love.graphics.newText(self.data.mainFont)
		if self.persist.searchQuery and #self.persist.searchQuery > 0 then
			self.data.searchText:add(table.concat(self.persist.searchQuery), 0, 0, 0, 22/44)
		else
			self.data.searchText:add(L"beatmapSelect:searchPrompt", 0, 0, 0, 22/44)
		end
	end

	if self.data.openDirectory == nil then
		self.data.openDirectory = CircleIconButton(color.hex333131, 36, self.assets.images.folder, 0.64, ColorTheme.get())
		self.data.openDirectory:addEventListener("mousereleased", function(_, url)
			love.system.openURL(url)
		end)
		self.data.openDirectory:setData("file://"..love.filesystem.getSaveDirectory().."/beatmap")
	end
	Glow.addFixedElement(self.data.openDirectory, 856, 4)

	if self.data.downloadBeatmap == nil then
		self.data.downloadBeatmap = CircleIconButton(color.hex333131, 36, self.assets.images.downloadCircle, 0.64, ColorTheme.get())
		self.data.downloadBeatmap:addEventListener("mousereleased", function()
			Gamestate.enter(LoadingInstance.getInstance(), "beatmapDownload")
		end)
		self.data.downloadBeatmap:setData(self)
	end
	Glow.addFixedElement(self.data.downloadBeatmap, 776, 4)

	if fileDialog.isSupported() then
		if self.data.addBeatmap == nil then
			self.data.addBeatmap = CircleIconButton(color.hex333131, 36, self.assets.images.add, 0.64, ColorTheme.get())
			self.data.addBeatmap:addEventListener("mousereleased", function()
				-- this block but oh well
				local list = fileDialog.open(L"beatmapSelect:insert", nil, nil, true)
				if #list > 0 then
					self.persist.beatmapUpdate = list
				end
			end)
		end

		Glow.addFixedElement(self.data.addBeatmap, 696, 4)
	end

	if self.data.deleteBeatmap == nil then
		self.data.deleteBeatmap = CircleIconButton(color.hexFFFFFF, 18, self.assets.images.delete, 0.32, ColorTheme.get())
		self.data.deleteBeatmap:addEventListener("mousereleased", function()
			if not(self.persist.selectedBeatmap) then
				return
			end

			local target = self.persist.beatmaps[self.persist.selectedBeatmap]
			local message

			if target.group then
				message = L("beatmapSelect:deleteGroup", {
					id = target.group,
					name = target.name,
				})
			else
				message = L("beatmapSelect:deleteSingle", {
					id = target.id,
					name = target.name,
					diff = target.difficulty or L"beatmapSelect:diffUnknown"
				})
			end

			-- love.window.showMessageBox is confusing (notice `enterbutton` and `escapebutton`)
			-- "Yes" is 2, "No" is 1
			local messageButton = {L"dialog:no", L"dialog:yes", enterbutton = 2, escapebutton = 2}
			if love.window.showMessageBox(L"beatmapSelect:delete", message, messageButton, "warning") == 2 then
				-- Delete, only need to use the first id
				local firstID = target.group and target.beatmaps[1].id or target.id
				local index = self.persist.selectedBeatmap
				table.remove(self.persist.beatmaps, self.persist.selectedBeatmap)
				self.persist.beatmapFrame:removeElement(target.element)
				target = nil
				self.persist.beatmapSummary = nil
				self.persist.beatmapNameHeight = 0
				self.persist.beatmapCoverArt = nil
				self.persist.selectedBeatmap = nil
				self.persist.replaysFrame:clear()
				self.data.difficultyDropdown:hide()
				Glow.removeElement(self.data.deleteBeatmap)

				-- Move element
				for i = index, #self.persist.beatmaps do
					local v = self.persist.beatmaps[i]
					v.element:setData(i)
				end

				-- Force GC
				collectgarbage()
				collectgarbage()
				-- Send delete command
				BeatmapList.deleteBeatmap(firstID)
				-- Set status text
				updateBeatmapList(self)
				--setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}), false)
			end
		end)
	end

	-- Option toggle
	if self.data.autoplayToggle == nil then
		self.data.autoplayToggle = createOptionToggleSetting(
			"AUTOPLAY",
			self.assets.images.fastForward, 0.32, 44,
			self.data.mainFont2, L"beatmapSelect:optionAutoplay", 60
		)
	end
	Glow.addFixedElement(self.data.autoplayToggle, 480, 248)

	if self.data.randomToggle == nil then
		self.data.randomToggle = optionToggleButton(
			false,
			self.assets.images.shuffle, 0.32, 44,
			self.data.mainFont2, L"beatmapSelect:optionRandom", 60
		)
	end
	Glow.addFixedElement(self.data.randomToggle, 600, 248)

	if self.data.storyToggle == nil then
		self.data.storyToggle = createOptionToggleSetting(
			"STORYBOARD",
			self.assets.images.video, 0.32, 44,
			self.data.mainFont2, L"beatmapSelect:optionStoryboard", 60
		)
	end
	Glow.addFixedElement(self.data.storyToggle, 720, 248)

	if self.data.videoToggle == nil then
		self.data.videoToggle = createOptionToggleSetting(
			"VIDEOBG",
			self.assets.images.movie, 0.32, 44,
			self.data.mainFont2, L"beatmapSelect:optionVideo", 60
		)
	end
	Glow.addFixedElement(self.data.videoToggle, 840, 248)

	if self.data.playButton == nil then
		self.data.playButton = playButton(self.data.mainFont2, self.assets.images.play)
		self.data.playButton:addEventListener("mousereleased", startPlayBeatmap)
		self.data.playButton:setData(self)
	end
	do
		local width = self.data.playButton.width
		-- Place in between "Random" and "Storyboard" text
		Glow.addFixedElement(self.data.playButton, 720 - width * 0.5, 336)
	end

	if self.data.difficultyButton == nil then
		local b = diffText(self.data.mainFont2, self.assets.images.dropDown)
		b:addEventListener("mousereleased", function()
			local target = self.persist.beatmaps[self.persist.selectedBeatmap]

			if target.group then
				if self.data.difficultyDropdown:isShown() then
					self.data.difficultyDropdown:hide()
				else
					self.data.difficultyDropdown:setData(target)
					self.data.difficultyDropdown:setItems(target.difficulty)
					self.data.difficultyDropdown:show(self.persist.dropdownFrame, 508, 232)
				end
			end
		end)

		if self.persist.selectedBeatmap then
			local selectedBeatmap = self.persist.beatmaps[self.persist.selectedBeatmap]

			if selectedBeatmap.group then
				b:setText(selectedBeatmap.difficulty[selectedBeatmap.selected], true)
			else
				b:setText(selectedBeatmap.difficulty, false)
			end
		end

		self.data.difficultyButton = b
	end
	Glow.addFixedElement(self.data.difficultyButton, 508, 206)

	if self.data.difficultyDropdown == nil then
		self.data.difficultyDropdown = diffDropdown(self.data.mainFont2)
		self.data.difficultyDropdown:addEventListener("itemselected", function(_, target, index, name)
			target.selected = index
			self.data.difficultyButton:setText(name, true)

			BeatmapList.getSummary(target.beatmaps[index].id, self.persist.summaryGet)
		end)
	end
end

function beatmapSelect:start()
	self.persist.beatmapFrame = Glow.Frame(0, 152, 480, 488)
	self.persist.replaysFrame = Glow.Frame(480, 398, 480, 242)
	self.persist.dropdownFrame = Glow.Frame(0, 0, 960, 640)
	self.persist.beatmaps = {sorted = false}
	self.persist.selectedBeatmap = nil
	self.persist.beatmapSummary = nil
	self.persist.beatmapUpdate = nil
	self.persist.beatmapNameHeight = 0
	self.persist.active = true
	self.persist.beatmapText = love.graphics.newText(self.data.mainFont, L"beatmapSelect:beatmaps")
	self.persist.statusText = love.graphics.newText(self.data.mainFont)
	self.persist.statusTextBlink = math.huge
	self.persist.searchQuery = {}

	self.persist.beatmapFrame:setSliderColor(color.hex434242)
	self.persist.beatmapFrame:setVerticalSliderPosition("left")
	self.persist.replaysFrame:setSliderColor(color.white)
	self.persist.replaysFrame:setSliderHandleColor(ColorTheme.get())
	self.persist.emptyReplays = false

	self.persist.summaryGet = function(d)
		local target = self.persist.beatmaps[self.persist.selectedBeatmap]
		self.persist.beatmapSummary = d

		if d.coverArt and d.coverArt.image then
			self.persist.beatmapCoverArt = love.graphics.newImage(d.coverArt.image, mipmaps)
		end

		local beatmapTarget = target

		if target.group then
			beatmapTarget = target.beatmaps[target.selected]
		end

		if beatmapTarget.replays == nil then
			beatmapTarget.replays = enumerateReplays(beatmapTarget.id, d.hash)
		end

		self.persist.beatmapNameHeight =
			#select(2, self.data.mainFont:getWrap(beatmapTarget.name, 300 / (24/44))) *
			self.data.mainFont:getHeight() * (24/44)

		self.persist.replaysFrame:clear()
		if #beatmapTarget.replays > 0 then
			self.persist.emptyReplays = false

			local function replayCallback(_, replay)
				local comboRange = nil
				local summary = self.persist.beatmapSummary
				local targetBeatmap = self.persist.beatmaps[self.persist.selectedBeatmap]

				if targetBeatmap.group then
					targetBeatmap = targetBeatmap.beatmaps[targetBeatmap.selected]
				end

				if self.persist.beatmapSummary.comboS then
					comboRange = {
						summary.comboC,
						summary.comboB,
						summary.comboA,
						summary.comboS
					}
				end

				Gamestate.enter(LoadingInstance.getInstance(), "result", {
					name = targetBeatmap.id,
					summary = summary,
					replay = replay,
					allowRetry = false,
					allowSave = false,
					autoplay = false,
					comboRange = comboRange
				})
			end

			for i, v in ipairs(beatmapTarget.replays) do
				local elem = replayButton(self, v)
				elem:addEventListener("mousereleased", replayCallback)
				elem:setData(v)
				self.persist.replaysFrame:addElement(elem, 4, (i - 1) * 72)
			end
		else
			self.persist.emptyReplays = true
		end

		Glow.removeElement(self.data.deleteBeatmap)
		Glow.addElement(self.data.deleteBeatmap, 742, 198)
	end

	local function beatmapSelected(_, index)
		if self.persist.selectedBeatmap ~= nil and self.persist.beatmapSummary == nil then
			-- Not fully loading
			return
		end

		self.data.difficultyDropdown:hide()

		local target = self.persist.beatmaps[index]
		for i, v in ipairs(self.persist.beatmaps) do
			v.element.selected = i == index
		end

		if target.group then
			BeatmapList.getSummary(target.beatmaps[target.selected].id, self.persist.summaryGet)
			self.data.difficultyButton:setText(target.difficulty[target.selected], true)
		else
			BeatmapList.getSummary(target.id, self.persist.summaryGet)
			self.data.difficultyButton:setText(target.difficulty, false)
		end

		self.persist.beatmapCoverArt = nil
		self.persist.beatmapSummary = nil
		self.persist.selectedBeatmap = index
	end

	local unprocessedBeatmaps = {}

	-- Lock fonts
	self.persist.mainFont = self.data.mainFont
	self.persist.formatFont = self.assets.fonts.formatFont
	BeatmapList.push()
	BeatmapList.enumerate(function(id, name, fmt, diff, _, group)
		if id == "" then
			for _, v in ipairs(unprocessedBeatmaps) do
				if v.group then
					-- look for existing
					local targetGroup

					for _, w in ipairs(self.persist.beatmaps) do
						if w.group == v.group then
							targetGroup = w
							break
						end
					end

					-- create new group
					if not(targetGroup) then
						targetGroup = {
							name = v.name,
							format = v.format,
							beatmaps = {},
							difficulty = {},
							group = v.group,
							selected = 1,
							element = beatmapSelectButton(self, v.name, v.format)
						}

						BeatmapList.getCoverArt(v.id, function(has, img, info)
							local imageCover = nil

							if has then
								local image = love.graphics.newImage(img, mipmaps)
								local w, h = image:getDimensions()
								Util.releaseObject(img)
								targetGroup.coverArtImage = image
								targetGroup.info = info

								if w > 128 or h > 128 then
									imageCover = resizeImage(image, 128, 128)
									Util.releaseObject(image)
								else
									imageCover = image
								end
							end

							targetGroup.element:setCoverImage(imageCover)
							targetGroup.element:addEventListener("mousereleased", beatmapSelected)
						end)

						self.persist.beatmaps[#self.persist.beatmaps + 1] = targetGroup
					end

					targetGroup.beatmaps[#targetGroup.beatmaps + 1] = v
					targetGroup.difficulty[#targetGroup.difficulty + 1] = v.difficulty
				else
					v.element = beatmapSelectButton(self, v.name, v.format)
					self.persist.beatmaps[#self.persist.beatmaps + 1] = v

					if BeatmapList.isActive() then
						BeatmapList.getCoverArt(v.id, function(has, img, info)
							local imageCover = nil

							if has then
								local image = love.graphics.newImage(img, mipmaps)
								local w, h = image:getDimensions()
								Util.releaseObject(img)
								v.coverArtImage = image
								v.info = info

								if w > 128 or h > 128 then
									imageCover = resizeImage(image, 128, 128)
									Util.releaseObject(image)
								else
									imageCover = image
								end
							end

							v.element:setCoverImage(imageCover)
							v.element:addEventListener("mousereleased", beatmapSelected)
						end)
					end
				end
			end

			-- sort
			table.sort(self.persist.beatmaps, function(a, b)
				return a.name < b.name
			end)

			for i, v in ipairs(self.persist.beatmaps) do
				v.element:setData(i)
			end

			self.persist.beatmaps.sorted = true

			if self.persist.active then
				updateBeatmapList(self)
				setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}), false)
			end

			-- Unlock fonts
			self.persist.mainFont = nil
			self.persist.formatFont = nil

			return false
		end

		unprocessedBeatmaps[#unprocessedBeatmaps + 1] = {
			id = id,
			name = name,
			format = fmt,
			difficulty = diff,
			group = group
		}
		return true
	end)

	Glow.addFrame(self.persist.beatmapFrame)
	Glow.addFrame(self.persist.replaysFrame)
	Glow.addFrame(self.persist.dropdownFrame)
	setStatusText(self, L"beatmapSelect:loading", true)
end

function beatmapSelect:exit()
	self.persist.active = false
	BeatmapList.pop(true)
end

function beatmapSelect:resumed()
	self.persist.active = true
	if self.persist.beatmaps.sorted then
		setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}), false)
	end

	if self.persist.selectedBeatmap then
		Glow.addElement(self.data.deleteBeatmap, 742, 198)
	end

	Glow.addFrame(self.persist.replaysFrame)
	Glow.addFrame(self.persist.beatmapFrame)
	Glow.addFrame(self.persist.dropdownFrame)
end

function beatmapSelect:paused()
	self.persist.active = false
end

function beatmapSelect:update(dt)
	if self.persist.beatmapUpdate then
		Gamestate.replace(nil, "beatmapInsert", self.persist.beatmapUpdate)
		self.persist.beatmapUpdate = nil
	end

	self.persist.beatmapFrame:update(dt)
	self.persist.replaysFrame:update(dt)
	self.persist.dropdownFrame:update(dt)

	if self.persist.statusTextBlink ~= math.huge then
		self.persist.statusTextBlink = (self.persist.statusTextBlink + dt) % 2
	end
end

function beatmapSelect:draw()
	love.graphics.setColor(color.hex434242)
	love.graphics.rectangle("fill", -88, -43, 1136, 726)
	love.graphics.setColor(ColorTheme.get())
	love.graphics.rectangle("fill", 480, 10, 480, 673)

	local shader = love.graphics.getShader()
	love.graphics.setShader(Util.drawText.workaroundShader)
	love.graphics.setColor(color.white)
	love.graphics.rectangle("fill", 484, 346, 472, 294)
	love.graphics.draw(self.persist.beatmapText, 30, 93)
	if self.persist.statusTextBlink ~= math.huge then
		love.graphics.setColor(color.compat(255, 255, 255, math.abs(1 - self.persist.statusTextBlink)))
	end
	love.graphics.draw(self.persist.statusText)
	love.graphics.setColor(ColorTheme.get())
	love.graphics.draw(self.data.replaysText, 500, 374)
	love.graphics.setColor(color.white)

	if self.persist.selectedBeatmap and self.persist.beatmapSummary then
		local v = assert(self.persist.beatmaps[self.persist.selectedBeatmap])
		local summary = self.persist.beatmapSummary
		love.graphics.setFont(self.data.mainFont)
		love.graphics.printf(v.name, 500, 98, 300 / (24/44), "left", 0, 24/44)

		if summary.coverArt and summary.coverArt.info then
			-- FIXME: Implement better caching for this table creation
			local _, info = self.data.mainFont2:getWrap(v.info, 300)
			love.graphics.setFont(self.data.mainFont2)
			love.graphics.printf(table.concat(info, "\n", 1, math.min(#info, 4)), 500, 98 + self.persist.beatmapNameHeight, 300 / (9/16), "left", 0, 9/16)
		end

		if self.persist.beatmapCoverArt then
			local w, h = self.persist.beatmapCoverArt:getDimensions()
			love.graphics.setShader(self.data.coverMaskShader)
			love.graphics.draw(self.persist.beatmapCoverArt, 806, 94, 0, 140 / w, 140 / h)
		else
			love.graphics.setColor(color.hexC4C4C4)
			love.graphics.rectangle("fill", 806, 94, 140, 140, 15, 15)
			love.graphics.rectangle("line", 806, 94, 140, 140, 15, 15)
			love.graphics.setColor(color.white)
		end
	else
		love.graphics.setColor(color.hexC4C4C4)
		love.graphics.rectangle("fill", 806, 94, 140, 140, 15, 15)
		love.graphics.rectangle("line", 806, 94, 140, 140, 15, 15)
		love.graphics.setColor(color.white)
	end

	love.graphics.setShader(shader)
	love.graphics.draw(self.data.shadowGradient, -88, 77, 0, 1136, 8)
	love.graphics.setColor(color.hex333131)
	love.graphics.rectangle("fill", -88, 0, 1136, 80)
	love.graphics.setColor(#self.persist.searchQuery > 0 and color.white or color.hexC0C0C0)
	Util.drawText(self.data.searchText, 192, 24)

	if self.persist.emptyReplays then
		love.graphics.setColor(color.hex8B8B8B)
		love.graphics.draw(self.assets.images.poll, 720, 488, 0, 0.32, 0.32, 46, 46)
		Util.drawText(self.data.emptyReplaysText, 720, 500)
	end

	Glow.draw()
	self.persist.beatmapFrame:draw()
	self.persist.replaysFrame:draw()
	self.persist.dropdownFrame:draw()
end

beatmapSelect:registerEvent("mousereleased", function(self)
	self.data.difficultyDropdown:hide()
end)

beatmapSelect:registerEvent("keypressed", function(self, key)
	if key == "backspace" then
		self.persist.searchQuery[#self.persist.searchQuery] = nil
		updateBeatmapList(self)
	end
end)

beatmapSelect:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

beatmapSelect:registerEvent("filedropped", function(self, file)
	self.persist.beatmapUpdate = self.persist.beatmapUpdate or {}
	self.persist.beatmapUpdate[#self.persist.beatmapUpdate + 1] = file
end)

beatmapSelect:registerEvent("textinput", function(self, str)
	if not(Gamestate.preparedGamestate) then
		self.persist.searchQuery[#self.persist.searchQuery + 1] = str
		updateBeatmapList(self)
	end
end)

return beatmapSelect
