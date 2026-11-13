-- Timing calibration: tap along a metronome, measure the offset,
-- save it as GLOBAL_OFFSET so notes line up with what you hear.
-- Part of the SIF gift fork

local love = require("love")

local Gamestate = require("gamestate")
local LoadingInstance = require("loading_instance")
local Setting = require("setting")
local Volume = require("volume")

local Glow = require("game.afterglow")
local Sleek = require("game.ui.sleek")

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

local CENTER_X, CENTER_Y = 480, 360
local TARGET_RADIUS = 72
local RING_START_RADIUS = 180

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
	Glow.addFixedElement(self.data.againButton, CENTER_X - 250, 548)
	Glow.addFixedElement(self.data.saveButton, CENTER_X + 10, 548)
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
	Sleek.loadTheme()

	if self.data.back == nil then
		self.data.back = Sleek.backButton()
		self.data.back:addEventListener("mousereleased", leave)
	end
	Glow.addFixedElement(self.data.back, 24, 16)

	if self.data.tick == nil then
		self.data.tick = love.audio.newSource("sound/tap/sif/SE_306.ogg", "static")
	end
	self.data.tick:setVolume(Volume.get("se", 0.75))

	if self.data.startButton == nil then
		self.data.startButton = Sleek.Button({
			w = 260, h = 54, text = "Start", size = 20,
			fill = Sleek.color.accent, textColor = Sleek.color.white, shadow = true,
		})
		self.data.startButton:addEventListener("mousereleased", function() startRun(self) end)
	end
	if self.data.saveButton == nil then
		self.data.saveButton = Sleek.Button({
			w = 240, h = 54, text = "Save", size = 20,
			fill = Sleek.color.accent, textColor = Sleek.color.white, shadow = true,
		})
		self.data.saveButton:addEventListener("mousereleased", function() saveResult(self) end)
	end
	if self.data.againButton == nil then
		self.data.againButton = Sleek.Button({w = 240, h = 54, text = "Try again", size = 20, border = true})
		self.data.againButton:addEventListener("mousereleased", function() startRun(self) end)
	end
end

function calibration:start()
	self.persist.phase = "idle"
	self.persist.flash = 0
	self.persist.savedMs = nil
	Glow.addFixedElement(self.data.startButton, CENTER_X - 130, 440)
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
		return "right on the beat"
	end
end

local function centered(text, y, font, col)
	love.graphics.setFont(font)
	Sleek.setColor(col or Sleek.color.text)
	love.graphics.printf(text, 0, y, 960, "center")
end

function calibration:draw()
	Sleek.background()
	Sleek.header("Timing")

	local phase = self.persist.phase

	if phase == "idle" then
		Sleek.panel(180, 120, 600, 280, 28)
		centered("Tap along with the beat", 156, Sleek.font(30, "medium"))
		centered(
			"A steady beat will play. After four beats, tap anywhere\n"
			.."in time with it. After "..TARGET_TAPS.." taps you'll see if your taps\n"
			.."land early or late, and you can save the result.",
			214, Sleek.font(17), Sleek.color.muted)
		centered(string.format("Current offset: %d ms", currentOffsetSetting()), 340, Sleek.font(15), Sleek.color.faint)
	elseif phase == "run" then
		local now = love.timer.getTime()
		local inWarmup = now < beatTime(self, WARMUP_BEATS)

		centered(inWarmup and "Listen..." or "Tap along", 92, Sleek.font(32, "medium"))
		centered(string.format("%d / %d", #self.persist.offsets, TARGET_TAPS), 140, Sleek.font(18), Sleek.color.muted)

		-- shrinking ring toward the next beat
		local toNext = (beatTime(self, self.persist.nextBeat) - now) / INTERVAL
		toNext = math.min(math.max(toNext, 0), 1)
		local r = TARGET_RADIUS + (RING_START_RADIUS - TARGET_RADIUS) * toNext
		Sleek.setColor(Sleek.color.faint, 0.6)
		love.graphics.setLineWidth(2)
		love.graphics.circle("line", CENTER_X, CENTER_Y, r, 96)

		-- target circle, flashing on the beat
		local f = self.persist.flash
		local rr = TARGET_RADIUS * (1 + 0.1 * f)
		Sleek.setColor(Sleek.color.accentSoft)
		love.graphics.circle("fill", CENTER_X, CENTER_Y, rr, 96)
		Sleek.setColor(Sleek.color.accent, 0.35 + 0.65 * f)
		love.graphics.circle("fill", CENTER_X, CENTER_Y, rr - 10, 96)
		Sleek.setColor(Sleek.color.accent)
		love.graphics.setLineWidth(3)
		love.graphics.circle("line", CENTER_X, CENTER_Y, rr, 96)
		love.graphics.setLineWidth(1)

		if self.persist.lastTap then
			local ms = math.floor(self.persist.lastTap * 1000 + 0.5)
			centered(fmtOffset(ms), 572, Sleek.font(20, "medium"), ms > 0 and Sleek.color.goldDark or Sleek.color.blueDark)
		end
	elseif phase == "done" then
		Sleek.panel(120, 96, 720, 384, 28)
		centered("Your taps were "..fmtOffset(self.persist.resultMs), 126, Sleek.font(30, "medium"))
		local consistency
		if self.persist.spreadMs <= 25 then
			consistency = "Consistent."
		elseif self.persist.spreadMs <= 45 then
			consistency = "Fairly consistent. Another run may help."
		else
			consistency = "Quite scattered. Try another run before saving."
		end
		centered(string.format("Spread: about %d ms. %s", self.persist.spreadMs, consistency), 180, Sleek.font(17), Sleek.color.muted)

		-- tap scatter: one mark per tap on an early/late axis
		local bx, bw, by = 200, 560, 300
		Sleek.setColor(Sleek.color.track)
		love.graphics.rectangle("fill", bx, by - 2, bw, 4, 2, 2)
		Sleek.setColor(Sleek.color.border)
		love.graphics.rectangle("fill", bx + bw / 2 - 1, by - 26, 2, 52)
		love.graphics.setFont(Sleek.font(14))
		Sleek.setColor(Sleek.color.muted)
		love.graphics.print("early", bx, by + 20)
		love.graphics.printf("late", bx, by + 20, bw, "right")
		love.graphics.printf("on the beat", bx, by + 20, bw, "center")
		for _, off in ipairs(self.persist.offsets) do
			local t = math.min(math.max(off / ACCEPT_WINDOW, -1), 1)
			Sleek.setColor(off > 0 and Sleek.color.gold or Sleek.color.blue)
			love.graphics.rectangle("fill", bx + bw / 2 + t * bw / 2 - 1.5, by - 16, 3, 32, 1.5, 1.5)
		end

		centered(string.format("Offset now: %d ms.   After saving: %d ms.", currentOffsetSetting(), self.persist.resultMs),
			400, Sleek.font(16), Sleek.color.text)
		if self.persist.savedMs then
			centered("Saved.", 446, Sleek.font(18, "medium"), Sleek.color.accent)
		end
	end

	love.graphics.setColor(1, 1, 1, 1)
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
