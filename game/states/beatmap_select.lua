-- Beatmap selection (sleek restyle for the SIF gift fork)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")
local lsr = require("libs.lsr")

local Setting = require("setting")
local fileDialog = require("file_dialog")
local log = require("logging")
local Util = require("util")
local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local L = require("language")

local BeatmapList = require("game.beatmap.list")
local Glow = require("game.afterglow")
local Sleek = require("game.ui.sleek")

local mipmaps = {mipmaps = true}

-- Layout
local LIST_X, LIST_Y, LIST_W = 20, 88, 532
local ROW_W, ROW_H, ROW_STEP = 494, 56, 64
local PANEL_X, PANEL_Y, PANEL_W, PANEL_H = 568, 88, 372, 536
local PAD = 22
local COVER = 104
local DIFF_Y = PANEL_Y + PAD + COVER + 18
local OPT_Y = DIFF_Y + 54
local REPLAY_Y = OPT_Y + 2 * 50 + 16
local PLAY_H = 54
local PLAY_Y = PANEL_Y + PANEL_H - PAD - PLAY_H

local beatmapSelectButton = Luaoop.class("Livesim2.BeatmapSelect.SleekRow", Glow.Element)
local optionToggleButton = Luaoop.class("Livesim2.BeatmapSelect.SleekSwitch", Glow.Element)
local diffPills = Luaoop.class("Livesim2.BeatmapSelect.SleekDiffPills", Glow.Element)
local replayButton = Luaoop.class("Livesim2.BeatmapSelect.SleekReplay", Glow.Element)
local roundIcon = Luaoop.class("Livesim2.BeatmapSelect.SleekRoundIcon", Glow.Element)

local function ellipsize(font, text, w)
	if font:getWidth(text) <= w then return text end
	local t = text
	while #t > 1 and font:getWidth(t.."…") > w do
		t = t:sub(1, -2)
		-- don't cut a UTF-8 sequence in half
		while #t > 0 and t:byte(-1) >= 128 and t:byte(-1) < 192 do t = t:sub(1, -2) end
		if #t > 0 and t:byte(-1) >= 192 then t = t:sub(1, -2) end
	end
	return t.."…"
end

local function pressable(self)
	self.isPressed = false
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

---------------------------------------------------------------- list row

function beatmapSelectButton:new(state, name, subtitle, coverImage)
	self.name = name
	self.subtitle = subtitle or ""
	self:setCoverImage(coverImage)
	self.width, self.height = ROW_W, ROW_H
	self.selected = false
	pressable(self)
end

function beatmapSelectButton:setCoverImage(coverImage)
	self.coverImage = coverImage
end

function beatmapSelectButton:render(x, y)
	local r = ROW_H / 2
	Sleek.setColor(Sleek.color.panel)
	love.graphics.rectangle("fill", x, y, self.width, self.height, r, r, 32)
	if self.selected then
		Sleek.setColor(Sleek.color.accent)
		love.graphics.setLineWidth(2)
		love.graphics.rectangle("line", x + 1, y + 1, self.width - 2, self.height - 2, r - 1, r - 1, 32)
		love.graphics.setLineWidth(1)
	else
		Sleek.setColor(Sleek.color.border)
		love.graphics.rectangle("line", x, y, self.width, self.height, r, r, 32)
	end

	local cx, cy = x + 6 + 22, y + r
	if self.coverImage then
		Sleek.drawCircleImage(self.coverImage, cx, cy, 22)
	else
		Sleek.setColor(Sleek.color.accentSoft)
		love.graphics.circle("fill", cx, cy, 22, 48)
		Sleek.iconNote(cx, cy, 22, Sleek.color.accentDark)
	end

	local nameFont, subFont = Sleek.font(17, "medium"), Sleek.font(12)
	local tx = x + 6 + 44 + 14
	local tw = self.width - (tx - x) - 20
	Sleek.setColor(Sleek.color.text)
	love.graphics.setFont(nameFont)
	love.graphics.print(ellipsize(nameFont, self.name, tw), tx, y + 8)
	Sleek.setColor(Sleek.color.muted)
	love.graphics.setFont(subFont)
	love.graphics.print(ellipsize(subFont, self.subtitle, tw), tx, y + 32)

	if self.isPressed then
		love.graphics.setColor(0, 0, 0, 0.05)
		love.graphics.rectangle("fill", x, y, self.width, self.height, r, r, 32)
	end
end

---------------------------------------------------------------- option switch

local SWITCH_W = (PANEL_W - PAD * 2 - 10) / 2

function optionToggleButton:new(checked, text)
	self.text = text
	self.width, self.height = SWITCH_W, 42
	self.checked = not(not(checked))
	self.knob = self.checked and 1 or 0
	pressable(self)
	self:addEventListener("mousereleased", optionToggleButton._released)
end

function optionToggleButton:_released()
	self.checked = not(self.checked)
	self:triggerEvent("changed", self.checked)
end

function optionToggleButton:update(dt)
	local target = self.checked and 1 or 0
	if self.knob < target then
		self.knob = math.min(self.knob + dt * 8, 1)
	elseif self.knob > target then
		self.knob = math.max(self.knob - dt * 8, 0)
	end
end

function optionToggleButton:render(x, y)
	local h = self.height
	Sleek.setColor(Sleek.color.panel)
	love.graphics.rectangle("fill", x, y, self.width, h, h / 2, h / 2, 32)
	Sleek.setColor(Sleek.color.border)
	love.graphics.rectangle("line", x, y, self.width, h, h / 2, h / 2, 32)

	local font = Sleek.font(14)
	love.graphics.setFont(font)
	Sleek.setColor(Sleek.color.text)
	love.graphics.print(self.text, x + 14, y + (h - font:getHeight()) / 2)

	-- switch
	local sw, sh = 40, 24
	local sx, sy = x + self.width - 8 - sw, y + (h - sh) / 2
	Sleek.setColor(self.checked and Sleek.color.accent or Sleek.color.grey)
	love.graphics.rectangle("fill", sx, sy, sw, sh, sh / 2, sh / 2, 24)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.circle("fill", sx + 12 + self.knob * (sw - 24), sy + sh / 2, 9, 24)

	if self.isPressed then
		love.graphics.setColor(0, 0, 0, 0.05)
		love.graphics.rectangle("fill", x, y, self.width, h, h / 2, h / 2, 32)
	end
end

---------------------------------------------------------------- difficulty pills

function diffPills:new()
	self.width, self.height = PANEL_W - PAD * 2, 40
	self.items = {}
	self.selected = 1
	self.pressX = nil
	self:addEventListener("mousepressed", function(_, _, x) self.pressX = x end)
	self:addEventListener("mousecanceled", function() self.pressX = nil end)
	self:addEventListener("mousereleased", diffPills._released)
end

function diffPills:setItems(items, selected)
	self.items = items or {}
	self.selected = selected or 1
end

function diffPills:_released(_, x)
	self.pressX = nil
	local n = #self.items
	if n < 2 or not x then return end
	local idx = Util.clamp(math.floor(x / (self.width / n)) + 1, 1, n)
	if idx ~= self.selected then
		self.selected = idx
		self:triggerEvent("itemselected", idx, self.items[idx])
	end
end

function diffPills:render(x, y)
	local n = #self.items
	if n == 0 then return end
	local h = self.height
	Sleek.setColor(Sleek.color.track)
	love.graphics.rectangle("fill", x, y, self.width, h, h / 2, h / 2, 32)
	local w = self.width / n
	local font = Sleek.font(15, "medium")
	love.graphics.setFont(font)
	for i, name in ipairs(self.items) do
		local px = x + (i - 1) * w
		if i == self.selected then
			Sleek.setColor(Sleek.color.panel)
			love.graphics.rectangle("fill", px + 4, y + 4, w - 8, h - 8, (h - 8) / 2, (h - 8) / 2, 32)
			Sleek.setColor(Sleek.color.text)
		else
			Sleek.setColor(Sleek.color.muted)
		end
		love.graphics.printf(ellipsize(font, tostring(name), w - 16), px, y + (h - font:getHeight()) / 2, w, "center")
	end
end

---------------------------------------------------------------- replay row

function replayButton:new(state, replay)
	local time = os.date("*t", replay.timestamp)
	self.name = L("general:dateFormat", {
		month = state.data.monthNames[time.month],
		day = time.day,
		year = time.year
	})..string.format(" %02d:%02d", time.hour, time.min)
	self.score = tostring(replay.score)
	self.width, self.height = PANEL_W - PAD * 2 - 4, 40
	pressable(self)
end

function replayButton:render(x, y)
	local h = self.height
	Sleek.setColor(Sleek.color.panel)
	love.graphics.rectangle("fill", x, y, self.width, h, h / 2, h / 2, 32)
	Sleek.setColor(Sleek.color.border)
	love.graphics.rectangle("line", x, y, self.width, h, h / 2, h / 2, 32)
	local font = Sleek.font(14)
	love.graphics.setFont(font)
	Sleek.setColor(Sleek.color.muted)
	love.graphics.print(self.name, x + 16, y + (h - font:getHeight()) / 2)
	Sleek.setColor(Sleek.color.text)
	love.graphics.setFont(Sleek.font(15, "medium"))
	love.graphics.printf(self.score, x, y + (h - font:getHeight()) / 2, self.width - 16, "right")
	if self.isPressed then
		love.graphics.setColor(0, 0, 0, 0.05)
		love.graphics.rectangle("fill", x, y, self.width, h, h / 2, h / 2, 32)
	end
end

---------------------------------------------------------------- round icon button

function roundIcon:new(size, drawIcon)
	self.width, self.height = size, size
	self.drawIcon = drawIcon
	pressable(self)
end

function roundIcon:render(x, y)
	local r = self.width / 2
	Sleek.setColor(Sleek.color.panel)
	love.graphics.circle("fill", x + r, y + r, r, 48)
	Sleek.setColor(Sleek.color.border)
	love.graphics.circle("line", x + r, y + r, r, 48)
	self.drawIcon(x + r, y + r, self.width)
	if self.isPressed then
		love.graphics.setColor(0, 0, 0, 0.06)
		love.graphics.circle("fill", x + r, y + r, r, 48)
	end
end

local function iconDownload(cx, cy, s)
	Sleek.setColor(Sleek.color.text)
	love.graphics.setLineWidth(2)
	love.graphics.line(cx, cy - s * 0.2, cx, cy + s * 0.08)
	love.graphics.line(cx - s * 0.12, cy - s * 0.04, cx, cy + s * 0.08, cx + s * 0.12, cy - s * 0.04)
	love.graphics.line(cx - s * 0.2, cy + s * 0.18, cx + s * 0.2, cy + s * 0.18)
	love.graphics.setLineWidth(1)
end

local function iconFolder(cx, cy, s)
	Sleek.setColor(Sleek.color.text)
	love.graphics.setLineWidth(2)
	love.graphics.line(
		cx - s * 0.22, cy + s * 0.16, cx - s * 0.22, cy - s * 0.16, cx - s * 0.06, cy - s * 0.16,
		cx - s * 0.02, cy - s * 0.1, cx + s * 0.22, cy - s * 0.1, cx + s * 0.22, cy + s * 0.16, cx - s * 0.22, cy + s * 0.16
	)
	love.graphics.setLineWidth(1)
end

local function iconAdd(cx, cy, s)
	Sleek.setColor(Sleek.color.text)
	love.graphics.setLineWidth(2)
	love.graphics.line(cx - s * 0.18, cy, cx + s * 0.18, cy)
	love.graphics.line(cx, cy - s * 0.18, cx, cy + s * 0.18)
	love.graphics.setLineWidth(1)
end

local function iconTrash(cx, cy, s)
	Sleek.setColor(Sleek.color.muted)
	love.graphics.setLineWidth(1.6)
	love.graphics.line(cx - s * 0.22, cy - s * 0.16, cx + s * 0.22, cy - s * 0.16)
	love.graphics.line(cx - s * 0.08, cy - s * 0.16, cx - s * 0.08, cy - s * 0.24, cx + s * 0.08, cy - s * 0.24, cx + s * 0.08, cy - s * 0.16)
	love.graphics.line(cx - s * 0.16, cy - s * 0.12, cx - s * 0.12, cy + s * 0.24, cx + s * 0.12, cy + s * 0.24, cx + s * 0.16, cy - s * 0.12)
	love.graphics.setLineWidth(1)
end

---------------------------------------------------------------- helpers

local function leave()
	return Gamestate.leave(LoadingInstance.getInstance())
end

local function setStatusText(self, text, blink)
	self.persist.statusString = text or ""
	self.persist.statusTextBlink = blink and 0 or math.huge
end

local function createOptionToggleSetting(settingName, text)
	local x = optionToggleButton(Setting.get(settingName) == 1, text)
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
	love.graphics.setColor(1, 1, 1, 1)
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

	if #self.persist.searchQuery > 0 then
		local i = 1
		local query = table.concat(self.persist.searchQuery)
		local queryLower = query:lower()

		for _, v in ipairs(self.persist.beatmaps) do
			if v.name:lower():find(queryLower, 1, true) then
				self.persist.beatmapFrame:addElement(v.element, 4, (i - 1) * ROW_STEP + 4)
				i = i + 1
			end
		end

		setStatusText(self, L("beatmapSelect:searchResult", {amount = i - 1}))
	else
		for i, v in ipairs(self.persist.beatmaps) do
			self.persist.beatmapFrame:addElement(v.element, 4, (i - 1) * ROW_STEP + 4)
		end

		setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}))
	end
end

local function rowSubtitle(v)
	if v.group then
		return table.concat(v.difficulty, ", ")
	end
	return v.difficulty or v.format or ""
end

local beatmapSelect = Gamestate.create {
	images = {},
	fonts = {},
}

local function setSearchKeyboard(self, shown)
	self.persist.searchKeyboard = shown
	love.keyboard.setTextInput(shown)
end

local SEARCH_W = 248

function beatmapSelect:load()
	Glow.clear()
	Sleek.loadTheme()

	if self.data.monthNames == nil then
		local t = {}
		for w in L("general:months"):gmatch("%S+") do
			t[#t + 1] = w
		end
		self.data.monthNames = t
	end

	if self.data.back == nil then
		self.data.back = Sleek.backButton()
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 24, 16)

	-- header buttons, right to left: folder, download, (add), search
	local hx = 936 - 44
	if self.data.openDirectory == nil then
		self.data.openDirectory = roundIcon(44, iconFolder)
		self.data.openDirectory:addEventListener("mousereleased", function(_, url)
			love.system.openURL(url)
		end)
		self.data.openDirectory:setData("file://"..love.filesystem.getSaveDirectory().."/beatmap")
	end
	if not Util.isMobile() then
		Glow.addFixedElement(self.data.openDirectory, hx, 16)
		hx = hx - 52
	end

	if self.data.downloadBeatmap == nil then
		self.data.downloadBeatmap = roundIcon(44, iconDownload)
		self.data.downloadBeatmap:addEventListener("mousereleased", function()
			Gamestate.enter(LoadingInstance.getInstance(), "beatmapDownload")
		end)
	end
	Glow.addFixedElement(self.data.downloadBeatmap, hx, 16)
	hx = hx - 52

	if fileDialog.isSupported() then
		if self.data.addBeatmap == nil then
			self.data.addBeatmap = roundIcon(44, iconAdd)
			self.data.addBeatmap:addEventListener("mousereleased", function()
				local list = fileDialog.open(L"beatmapSelect:insert", nil, nil, true)
				if #list > 0 then
					self.persist.beatmapUpdate = list
				end
			end)
		end
		Glow.addFixedElement(self.data.addBeatmap, hx, 16)
		hx = hx - 52
	end

	if self.data.search == nil then
		self.data.search = Sleek.Button({
			w = SEARCH_W, h = 44, border = true,
			icon = function(x, y, w, h)
				Sleek.iconSearch(x + 24, y + h / 2, 22, Sleek.color.muted)
				local q = self.persist.searchQuery and table.concat(self.persist.searchQuery) or ""
				local font = Sleek.font(15)
				love.graphics.setFont(font)
				if #q > 0 then
					Sleek.setColor(Sleek.color.text)
				else
					Sleek.setColor(Sleek.color.faint)
					q = "Search songs"
				end
				love.graphics.print(ellipsize(font, q, w - 60), x + 44, y + (h - font:getHeight()) / 2)
				if self.persist.searchKeyboard then
					Sleek.setColor(Sleek.color.accent)
					love.graphics.rectangle("fill", x + 1, y + 1, 4, 4) -- tiny marker that typing is on
				end
			end
		})
		self.data.search:addEventListener("mousereleased", function()
			-- track the state ourselves: hasTextInput() is unreliable on iOS
			setSearchKeyboard(self, not(self.persist.searchKeyboard))
		end)
	end
	Glow.addFixedElement(self.data.search, hx + 44 - SEARCH_W, 16)

	if self.data.deleteBeatmap == nil then
		self.data.deleteBeatmap = roundIcon(34, iconTrash)
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

			-- "Yes" is 2, "No" is 1
			local messageButton = {L"dialog:no", L"dialog:yes", enterbutton = 2, escapebutton = 2}
			if love.window.showMessageBox(L"beatmapSelect:delete", message, messageButton, "warning") == 2 then
				local firstID = target.group and target.beatmaps[1].id or target.id
				local index = self.persist.selectedBeatmap
				table.remove(self.persist.beatmaps, self.persist.selectedBeatmap)
				self.persist.beatmapFrame:removeElement(target.element)
				target = nil
				self.persist.beatmapSummary = nil
				self.persist.beatmapCoverArt = nil
				self.persist.selectedBeatmap = nil
				self.persist.replaysFrame:clear()
				self.data.difficulty:setItems({})
				Glow.removeElement(self.data.deleteBeatmap)

				for i = index, #self.persist.beatmaps do
					local v = self.persist.beatmaps[i]
					v.element:setData(i)
				end

				collectgarbage()
				collectgarbage()
				BeatmapList.deleteBeatmap(firstID)
				updateBeatmapList(self)
			end
		end)
	end

	-- options
	local ox1, ox2 = PANEL_X + PAD, PANEL_X + PAD + SWITCH_W + 10
	if self.data.autoplayToggle == nil then
		self.data.autoplayToggle = createOptionToggleSetting("AUTOPLAY", L"beatmapSelect:optionAutoplay")
	end
	Glow.addFixedElement(self.data.autoplayToggle, ox1, OPT_Y)

	if self.data.randomToggle == nil then
		self.data.randomToggle = optionToggleButton(false, L"beatmapSelect:optionRandom")
	end
	Glow.addFixedElement(self.data.randomToggle, ox2, OPT_Y)

	if self.data.storyToggle == nil then
		self.data.storyToggle = createOptionToggleSetting("STORYBOARD", L"beatmapSelect:optionStoryboard")
	end
	Glow.addFixedElement(self.data.storyToggle, ox1, OPT_Y + 50)

	if self.data.videoToggle == nil then
		self.data.videoToggle = createOptionToggleSetting("VIDEOBG", "Video")
	end
	Glow.addFixedElement(self.data.videoToggle, ox2, OPT_Y + 50)

	if self.data.playButton == nil then
		self.data.playButton = Sleek.Button({
			w = PANEL_W - PAD * 2, h = PLAY_H, text = "Play", size = 22,
			fill = Sleek.color.accent, textColor = Sleek.color.white, shadow = true, textOffset = 10,
			icon = function(x, y, w, h)
				local font = Sleek.font(22, "medium")
				local tw = font:getWidth("Play")
				Sleek.iconPlay(x + w / 2 - tw / 2 - 10, y + h / 2, 18, Sleek.color.white)
			end
		})
		self.data.playButton:addEventListener("mousereleased", startPlayBeatmap)
		self.data.playButton:setData(self)
	end
	Glow.addFixedElement(self.data.playButton, PANEL_X + PAD, PLAY_Y)

	if self.data.difficulty == nil then
		local b = diffPills()
		b:addEventListener("itemselected", function(_, _, index)
			local target = self.persist.beatmaps[self.persist.selectedBeatmap]
			if target and target.group then
				target.selected = index
				self.persist.beatmapSummary = nil
				self.persist.beatmapCoverArt = nil
				BeatmapList.getSummary(target.beatmaps[index].id, self.persist.summaryGet)
			end
		end)

		if self.persist.selectedBeatmap then
			local selectedBeatmap = self.persist.beatmaps[self.persist.selectedBeatmap]
			if selectedBeatmap.group then
				b:setItems(selectedBeatmap.difficulty, selectedBeatmap.selected)
			else
				b:setItems({selectedBeatmap.difficulty or L"beatmapSelect:diffUnknown"}, 1)
			end
		end

		self.data.difficulty = b
	end
	Glow.addFixedElement(self.data.difficulty, PANEL_X + PAD, DIFF_Y)
end

function beatmapSelect:start()
	self.persist.beatmapFrame = Glow.Frame(LIST_X, LIST_Y, LIST_W, 640 - LIST_Y)
	self.persist.replaysFrame = Glow.Frame(PANEL_X + PAD, REPLAY_Y + 26, PANEL_W - PAD * 2 + 30, PLAY_Y - 12 - (REPLAY_Y + 26))
	self.persist.beatmaps = {sorted = false}
	self.persist.selectedBeatmap = nil
	self.persist.beatmapSummary = nil
	self.persist.beatmapUpdate = nil
	self.persist.active = true
	self.persist.statusString = ""
	self.persist.statusTextBlink = math.huge
	self.persist.searchQuery = {}
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
				self.persist.replaysFrame:addElement(elem, 2, (i - 1) * 46 + 2)
			end
		else
			self.persist.emptyReplays = true
		end

		Glow.removeElement(self.data.deleteBeatmap)
		Glow.addFixedElement(self.data.deleteBeatmap, PANEL_X + PANEL_W - PAD - 34, PANEL_Y + PAD)
	end

	local function beatmapSelected(_, index)
		if self.persist.selectedBeatmap ~= nil and self.persist.beatmapSummary == nil then
			-- Not fully loading
			return
		end

		local target = self.persist.beatmaps[index]
		for i, v in ipairs(self.persist.beatmaps) do
			v.element.selected = i == index
		end

		if target.group then
			BeatmapList.getSummary(target.beatmaps[target.selected].id, self.persist.summaryGet)
			self.data.difficulty:setItems(target.difficulty, target.selected)
		else
			BeatmapList.getSummary(target.id, self.persist.summaryGet)
			self.data.difficulty:setItems({target.difficulty or L"beatmapSelect:diffUnknown"}, 1)
		end

		self.persist.beatmapCoverArt = nil
		self.persist.beatmapSummary = nil
		self.persist.selectedBeatmap = index
	end

	local unprocessedBeatmaps = {}

	local function attachCover(entry, id)
		BeatmapList.getCoverArt(id, function(has, img, info)
			local imageCover = nil

			if has then
				local image = love.graphics.newImage(img, mipmaps)
				local w, h = image:getDimensions()
				Util.releaseObject(img)
				entry.coverArtImage = image
				entry.info = info

				if w > 128 or h > 128 then
					imageCover = resizeImage(image, 128, 128)
					Util.releaseObject(image)
				else
					imageCover = image
				end
			end

			entry.element:setCoverImage(imageCover)
			entry.element:addEventListener("mousereleased", beatmapSelected)
		end)
	end

	BeatmapList.push()
	BeatmapList.enumerate(function(id, name, fmt, diff, _, group)
		if id == "" then
			for _, v in ipairs(unprocessedBeatmaps) do
				if v.group then
					local targetGroup

					for _, w in ipairs(self.persist.beatmaps) do
						if w.group == v.group then
							targetGroup = w
							break
						end
					end

					if not(targetGroup) then
						targetGroup = {
							name = v.name,
							format = v.format,
							beatmaps = {},
							difficulty = {},
							group = v.group,
							selected = 1,
						}
						targetGroup.element = beatmapSelectButton(self, v.name, "")
						attachCover(targetGroup, v.id)
						self.persist.beatmaps[#self.persist.beatmaps + 1] = targetGroup
					end

					targetGroup.beatmaps[#targetGroup.beatmaps + 1] = v
					targetGroup.difficulty[#targetGroup.difficulty + 1] = v.difficulty
					targetGroup.element.subtitle = rowSubtitle(targetGroup)
				else
					v.element = beatmapSelectButton(self, v.name, rowSubtitle(v))
					self.persist.beatmaps[#self.persist.beatmaps + 1] = v

					if BeatmapList.isActive() then
						attachCover(v, v.id)
					end
				end
			end

			table.sort(self.persist.beatmaps, function(a, b)
				return a.name < b.name
			end)

			for i, v in ipairs(self.persist.beatmaps) do
				v.element:setData(i)
			end

			self.persist.beatmaps.sorted = true

			if self.persist.active then
				updateBeatmapList(self)
			end

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
	setStatusText(self, L"beatmapSelect:loading", true)
end

function beatmapSelect:exit()
	if self.persist.searchKeyboard then setSearchKeyboard(self, false) end
	self.persist.active = false
	BeatmapList.pop(true)
end

function beatmapSelect:resumed()
	Sleek.loadTheme()
	self.persist.active = true
	if self.persist.beatmaps.sorted then
		setStatusText(self, L("beatmapSelect:available", {amount = #self.persist.beatmaps}), false)
	end

	if self.persist.selectedBeatmap then
		Glow.addFixedElement(self.data.deleteBeatmap, PANEL_X + PANEL_W - PAD - 34, PANEL_Y + PAD)
	end

	Glow.addFrame(self.persist.replaysFrame)
	Glow.addFrame(self.persist.beatmapFrame)
end

function beatmapSelect:paused()
	if self.persist.searchKeyboard then setSearchKeyboard(self, false) end
	self.persist.active = false
end

function beatmapSelect:update(dt)
	if self.persist.beatmapUpdate then
		Gamestate.replace(nil, "beatmapInsert", self.persist.beatmapUpdate)
		self.persist.beatmapUpdate = nil
	end

	self.persist.beatmapFrame:update(dt)
	self.persist.replaysFrame:update(dt)
	Sleek.slimScrollbars(self.persist.beatmapFrame)
	Sleek.slimScrollbars(self.persist.replaysFrame)

	if self.persist.statusTextBlink ~= math.huge then
		self.persist.statusTextBlink = (self.persist.statusTextBlink + dt) % 2
	end
end

local function drawCover(img, x, y, size, r)
	Util.stencil11(function()
		love.graphics.rectangle("fill", x, y, size, size, r, r, 32)
	end, "replace", 1, false)
	Util.setStencilTest11("equal", 1)
	local w, h = img:getDimensions()
	local s = size / math.min(w, h)
	love.graphics.setColor(1, 1, 1, 1)
	love.graphics.draw(img, x + size / 2, y + size / 2, 0, s, s, w / 2, h / 2)
	Util.setStencilTest11()
end

function beatmapSelect:draw()
	Sleek.background("plain")

	-- list
	self.persist.beatmapFrame:draw()
	-- header strip over the list
	Sleek.setColor(Sleek.color.bg)
	love.graphics.rectangle("fill", -88, -43, 1136, LIST_Y + 43)

	-- title + status
	love.graphics.setFont(Sleek.font(28, "medium"))
	Sleek.setColor(Sleek.color.text)
	love.graphics.print("Songs", 84, 14)
	love.graphics.setFont(Sleek.font(14))
	local blinkA = 1
	if self.persist.statusTextBlink ~= math.huge then
		blinkA = math.abs(1 - self.persist.statusTextBlink)
	end
	Sleek.setColor(Sleek.color.muted, blinkA)
	love.graphics.print(self.persist.statusString or "", 85, 50)

	-- detail panel
	Sleek.panel(PANEL_X, PANEL_Y, PANEL_W, PANEL_H, 28)
	local cx, cy = PANEL_X + PAD, PANEL_Y + PAD
	local selected = self.persist.selectedBeatmap and self.persist.beatmaps[self.persist.selectedBeatmap]

	if self.persist.beatmapCoverArt then
		drawCover(self.persist.beatmapCoverArt, cx, cy, COVER, 24)
	else
		Sleek.setColor(Sleek.color.accentSoft)
		love.graphics.rectangle("fill", cx, cy, COVER, COVER, 24, 24, 32)
		Sleek.iconNote(cx + COVER / 2, cy + COVER / 2, 44, Sleek.color.accentDark)
	end

	local tx = cx + COVER + 16
	local tw = PANEL_X + PANEL_W - PAD - tx - (selected and 40 or 0)
	if selected then
		local titleFont = Sleek.font(20, "medium")
		love.graphics.setFont(titleFont)
		Sleek.setColor(Sleek.color.text)
		local _, lines = titleFont:getWrap(selected.name, tw)
		local shown = {}
		for i = 1, math.min(#lines, 3) do shown[i] = lines[i] end
		love.graphics.printf(table.concat(shown, "\n"), tx, cy, tw, "left")
		local ty = cy + #shown * titleFont:getHeight() + 4
		local info = selected.info
		if self.persist.beatmapSummary and info and #info > 0 then
			local f = Sleek.font(13)
			love.graphics.setFont(f)
			Sleek.setColor(Sleek.color.muted)
			local _, il = f:getWrap(info, tw + (selected and 40 or 0))
			local maxLines = math.max(math.floor((cy + COVER - ty) / f:getHeight()), 0)
			love.graphics.printf(table.concat(il, "\n", 1, math.min(#il, maxLines)), tx, ty, tw + 40, "left")
		end
	else
		love.graphics.setFont(Sleek.font(16))
		Sleek.setColor(Sleek.color.muted)
		love.graphics.printf("Pick a song from the list", tx, cy + COVER / 2 - 22, tw, "left")
	end

	-- replays
	love.graphics.setFont(Sleek.font(12, "medium"))
	Sleek.setColor(Sleek.color.muted)
	love.graphics.print("REPLAYS", PANEL_X + PAD + 2, REPLAY_Y + 4)
	if selected and self.persist.emptyReplays then
		love.graphics.setFont(Sleek.font(14))
		Sleek.setColor(Sleek.color.faint)
		love.graphics.print("None yet", PANEL_X + PAD + 2, REPLAY_Y + 30)
	end

	Glow.draw()
	self.persist.replaysFrame:draw()
end

beatmapSelect:registerEvent("mousereleased", function(self, x, y)
	-- tapping anywhere below the top bar closes the on-screen keyboard
	if self.persist.searchKeyboard and y and y > 80 then
		setSearchKeyboard(self, false)
	end
end)

beatmapSelect:registerEvent("keypressed", function(self, key)
	if key == "backspace" then
		self.persist.searchQuery[#self.persist.searchQuery] = nil
		updateBeatmapList(self)
	elseif (key == "return" or key == "kpenter") and self.persist.searchKeyboard then
		setSearchKeyboard(self, false)
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
