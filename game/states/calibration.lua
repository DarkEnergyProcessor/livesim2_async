-- Timing calibration: tap along a metronome, measure the offset,
-- save it as GLOBAL_OFFSET so notes line up with what you hear.
-- Part of the SIF gift fork

local love = require("love")
local Luaoop = require("libs.Luaoop")

local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local color = require("color")
local MainFont = require("main_font")
local Setting = require("setting")
local Volume = require("volume")

local Glow = require("game.afterglow")
local BackgroundLoader = require("game.background_loader")
local BackNavigation = require("game.ui.back_navigation")

local calibration = Gamestate.create {
	images = {},
	fonts = {}
}

-- Metronome parameters
local BPM = 120
local INTERVAL = 60 / BPM          -- seconds per beat
local WARMUP_BEATS = 4             -- listen-only beats before taps count
local TARGET_TAPS = 20             -- taps collected before showing results
local ACCEPT_WINDOW = 0.2          -- |offset| beyond this = stray tap, ignored

local CENTER_X, CENTER_Y = 480, 340
local TARGET_RADIUS = 72
local RING_START_RADIUS = 210

---------------------------------------------------------------- big button

local bigButton = Luaoop.class("Livesim2.CalibrationButton", Glow.Element)

function bigButton:new(text, w, fill)
	self.width, self.height = w or 240, 56
	self.text = text
	self.fill = fill or color.hexFFA73D
	self.font = MainFont.get(24)
	self.isPressed = false
	self:addEventListener("mousepressed", function() self.isPressed = true end)
	self:addEventListener("mousecanceled", function() self.isPressed = false end)
	self:addEventListener("mousereleased", function() self.isPressed = false end)
end

function bigButton:render(x, y)
	love.graphics.setColor(self.isPressed and color.white50PT or self.fill)
	love.graphics.rectangle("fill", x, y, self.width, self.height, 28, 28)
	love.graphics.setColor(color.white)
	love.graphics.setFont(self.font)
	love.graphics.printf(self.text, x, y + (self.height - self.font:getHeight()) / 2, self.width, "center")
end

---------------------------------------------------------------- helpers

local function median(list)
	local t = {}
	for i, v in ipairs(list) do t[i] = v end
	table.sort(t)
	local n = #t
	if n == 0 then return 0 end
	if n % 2 == 1 then
		return t[(n + 1) / 2]
	else
		return (t[n / 2] + t[n / 2 + 1]) * 0.5
	end
end

local function spread(list, mid)
	-- average absolute deviation from the median; robust and easy to read
	local n = #list
	if n == 0 then return 0 end
	local s = 0
	for _, v in ipairs(list) do s = s + math.abs(v - mid) end
	return s / n
end

local function beatTime(self, i)
	return self.persist.startTime + i * INTERVAL
end

local function startRun(self)
	self.persist.phase = "run"
	self.persist.startTime = love.timer.getTime() + 1 -- 1s of silence before beat 0
	self.persist.nextBeat = 0
	self.persist.offsets = {}
	self.persist.lastTap = nil
	self.persist.flash = 0
	Glow.removeElement(self.data.startButton)
	Glow.removeElement(self.data.saveButton)
	Glow.removeElement(self.data.againButton)
end

local function finishRun(self)
	self.persist.phase = "done"
	local mid = median(self.persist.offsets)
	self.persist.resultMs = math.floor(mid * 1000 + 0.5)
	self.persist.spreadMs = math.floor(spread(self.persist.offsets, mid) * 1000 + 0.5)
	Glow.addFixedElement(self.data.saveButton, CENTER_X - 250, 520)
	Glow.addFixedElement(self.data.againButton, CENTER_X + 10, 520)
end

local function registerTap(self)
	if self.persist.phase ~= "run" then return end
	local now = love.timer.getTime()
	local raw = (now - self.persist.startTime) / INTERVAL
	local nearest = math.floor(raw + 0.5)
	local offset = now - beatTime(self, nearest)
	if nearest < WARMUP_BEATS or math.abs(offset) > ACCEPT_WINDOW then
		return -- warm-up or stray tap
	end
	self.persist.offsets[#self.persist.offsets + 1] = offset
	self.persist.lastTap = offset
	if #self.persist.offsets >= TARGET_TAPS then
		finishRun(self)
	end
end

local function saveResult(self)
	Setting.set("GLOBAL_OFFSET", self.persist.resultMs)
	self.persist.savedMs = self.persist.resultMs
end

local function currentOffsetSetting()
	return tonumber(Setting.get("GLOBAL_OFFSET")) or 0
end

local function leave()
	return Gamestate.leave(LoadingInstance.getInstance())
end

---------------------------------------------------------------- state

function calibration:load()
	Glow.clear()

	if self.data.background == nil then
		self.data.background = BackgroundLoader.load(11)
	end
	if self.data.back == nil then
		self.data.back = BackNavigation("Timing")
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 0, 0)

	if self.data.tick == nil then
		self.data.tick = love.audio.newSource("sound/tap/sif/SE_306.ogg", "static")
	end
	self.data.tick:setVolume(Volume.get("se", 0.75))

	if self.data.startButton == nil then
		self.data.startButton = bigButton("Start", 260)
		self.data.startButton:addEventListener("mousereleased", function() startRun(self) end)
	end
	if self.data.saveButton == nil then
		self.data.saveButton = bigButton("Save", 240, color.hex55CAFD)
		self.data.saveButton:addEventListener("mousereleased", function() saveResult(self) end)
	end
	if self.data.againButton == nil then
		self.data.againButton = bigButton("Try again", 240)
		self.data.againButton:addEventListener("mousereleased", function() startRun(self) end)
	end

	self.data.bigFont = MainFont.get(40)
	self.data.font = MainFont.get(22)
	self.data.smallFont = MainFont.get(16)
end

function calibration:start()
	self.persist.phase = "idle"
	self.persist.flash = 0
	self.persist.savedMs = nil
	Glow.addFixedElement(self.data.startButton, CENTER_X - 130, 480)
end

function calibration:update(dt)
	if self.persist.phase == "run" then
		local now = love.timer.getTime()
		while now >= beatTime(self, self.persist.nextBeat) do
			-- only sound beats we're not hopelessly behind on (frame hitches)
			if now - beatTime(self, self.persist.nextBeat) < INTERVAL * 0.5 then
				self.data.tick:stop()
				self.data.tick:play()
				self.persist.flash = 1
			end
			self.persist.nextBeat = self.persist.nextBeat + 1
		end
	end
	self.persist.flash = math.max(self.persist.flash - dt * 5, 0)
end

local function fmtOffset(ms)
	if ms > 0 then
		return string.format("%d ms late", ms)
	elseif ms < 0 then
		return string.format("%d ms early", -ms)
	else
		return "spot on"
	end
end

function calibration:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	-- dim it so the circles read clearly
	love.graphics.setColor(color.compat(0, 0, 0, 0.5))
	love.graphics.rectangle("fill", -88, -43, 1136, 726)

	local phase = self.persist.phase

	if phase == "idle" then
		love.graphics.setColor(color.white)
		love.graphics.setFont(self.data.bigFont)
		love.graphics.printf("Timing check", 0, 120, 960, "center")
		love.graphics.setFont(self.data.font)
		love.graphics.printf(
			"A steady beat will play. Tap anywhere in time with it.\n"
			.."After "..TARGET_TAPS.." taps you'll see how early or late your taps land,\n"
			.."and the game can adjust itself to match.",
			80, 220, 800, "center")
		love.graphics.setFont(self.data.smallFont)
		love.graphics.printf(
			string.format("Current adjustment: %d ms", currentOffsetSetting()),
			0, 360, 960, "center")
	elseif phase == "run" then
		local now = love.timer.getTime()
		local inWarmup = now < beatTime(self, WARMUP_BEATS)

		-- shrinking ring toward the next beat
		local toNext = (beatTime(self, self.persist.nextBeat) - now) / INTERVAL
		toNext = math.min(math.max(toNext, 0), 1)
		local r = TARGET_RADIUS + (RING_START_RADIUS - TARGET_RADIUS) * toNext
		love.graphics.setColor(color.white50PT)
		love.graphics.setLineWidth(3)
		love.graphics.circle("line", CENTER_X, CENTER_Y, r)

		-- target circle, flashing on the beat
		local f = self.persist.flash
		love.graphics.setColor(color.compat(255, 255 - 88 * f, 255 - 194 * f, 0.6 + 0.4 * f))
		love.graphics.circle("fill", CENTER_X, CENTER_Y, TARGET_RADIUS * (1 + 0.12 * f))
		love.graphics.setColor(color.white)
		love.graphics.setLineWidth(4)
		love.graphics.circle("line", CENTER_X, CENTER_Y, TARGET_RADIUS * (1 + 0.12 * f))
		love.graphics.setLineWidth(1)

		love.graphics.setFont(self.data.bigFont)
		if inWarmup then
			love.graphics.printf("Listen...", 0, 96, 960, "center")
		else
			love.graphics.printf("Tap with the beat", 0, 96, 960, "center")
		end

		love.graphics.setFont(self.data.font)
		love.graphics.printf(
			string.format("%d / %d", #self.persist.offsets, TARGET_TAPS),
			0, 160, 960, "center")

		if self.persist.lastTap then
			local ms = math.floor(self.persist.lastTap * 1000 + 0.5)
			love.graphics.setColor(ms > 0 and color.hexFFA73D or color.hex55CAFD)
			love.graphics.printf(fmtOffset(ms), 0, 560, 960, "center")
		end
	elseif phase == "done" then
		love.graphics.setColor(color.white)
		love.graphics.setFont(self.data.bigFont)
		love.graphics.printf("Your taps: "..fmtOffset(self.persist.resultMs), 0, 130, 960, "center")

		love.graphics.setFont(self.data.font)
		local consistency
		if self.persist.spreadMs <= 25 then
			consistency = string.format("Spread: ±%d ms — nice and consistent.", self.persist.spreadMs)
		elseif self.persist.spreadMs <= 45 then
			consistency = string.format("Spread: ±%d ms — decent; a second run can tighten it.", self.persist.spreadMs)
		else
			consistency = string.format("Spread: ±%d ms — quite scattered; worth another run.", self.persist.spreadMs)
		end
		love.graphics.printf(consistency, 0, 210, 960, "center")

		love.graphics.printf(string.format(
			"Adjustment now: %d ms        After saving: %d ms",
			currentOffsetSetting(), self.persist.resultMs),
			0, 280, 960, "center")

		-- tap scatter: one notch per tap on an early/late axis
		local bx, bw, by = 180, 600, 380
		love.graphics.setColor(color.white50PT)
		love.graphics.rectangle("fill", bx, by, bw, 4)
		love.graphics.rectangle("fill", bx + bw / 2 - 1, by - 22, 3, 48)
		love.graphics.setFont(self.data.smallFont)
		love.graphics.print("early", bx - 2, by + 14)
		love.graphics.print("late", bx + bw - 28, by + 14)
		for _, off in ipairs(self.persist.offsets) do
			local t = math.min(math.max(off / ACCEPT_WINDOW, -1), 1)
			love.graphics.setColor(off > 0 and color.hexFFA73D or color.hex55CAFD)
			love.graphics.rectangle("fill", bx + bw / 2 + t * bw / 2 - 1, by - 14, 3, 32)
		end

		if self.persist.savedMs then
			love.graphics.setColor(color.hex55CAFD)
			love.graphics.setFont(self.data.font)
			love.graphics.printf("Saved!", 0, 470, 960, "center")
		end
	end

	love.graphics.setColor(color.white)
	Glow.draw()
end

-- tapping anywhere (except UI buttons, which Glow consumes) counts
calibration:registerEvent("mousepressed", function(self, _, y, b, ist)
	if ist or b > 1 then return end
	if y > 80 then registerTap(self) end
end)

calibration:registerEvent("touchpressed", function(self, _, _, y)
	if y > 80 then registerTap(self) end
end)

calibration:registerEvent("keypressed", function(self, key)
	if key ~= "escape" and self.persist.phase == "run" then
		registerTap(self)
	elseif key == "return" and self.persist.phase == "idle" then
		startRun(self)
	end
end)

calibration:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return calibration
