-- Replay system (record or replay)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local color = require("color")
local log = require("logging")
local replay = {
	recordedEvents = {},
	recordedTouchID = {[0] = "\0\0", ["\0\0"] = 0},
	recordedKey = {},
	replayEvents = {},
	replayTouchLine = {},
	replayTouchData = {},
	deltaT = 0,
	eventsToStdout = false,
}

function replay.clear(printEvents)
	replay.recordedEvents = {}
	replay.recordedTouchID = {[0] = "\0\0", ["\0\0"] = 0}
	replay.recordedKey = {false, false, false, false, false, false, false, false, false}
	replay.replayEvents = {}
	replay.replayTouchLine = {}
	replay.replayTouchData = {}
	replay.deltaT = 0
	replay.eventsToStdout = not(not(printEvents))

	if replay.eventsToStdout then
		io.stdout:write("record events to stdout start")
	end
end

local function replayPullIter()
	local ev = replay.replayEvents[1]
	if ev and replay.deltaT >= ev.time then
		return table.remove(replay.replayEvents, 1)
	end

	return nil
end

function replay.pull()
	return replayPullIter
end

function replay.setEventData(events)
	for i = 1, #events do
		replay.replayEvents[#replay.replayEvents + 1] = events[i]
	end
end

function replay.recordKeypressed(lane)
	if replay.recordedKey[lane] then return end
	log.debugf("replay", "keypressed lane %d", lane)
	replay.recordedEvents[#replay.recordedEvents + 1] = {
		type = "keyboard",
		mode = "pressed",
		key = lane,
		time = replay.deltaT
	}
	replay.recordedKey[lane] = true

	if replay.eventsToStdout then
		io.stdout:write(string.format("event:keyboard|time:%.6f|mode:pressed|key:", replay.deltaT), lane, "\n")
	end
end

function replay.recordKeyreleased(lane)
	if not(replay.recordedKey[lane]) then return end
	log.debugf("replay", "keyreleased lane %d", lane)
	replay.recordedEvents[#replay.recordedEvents + 1] = {
		type = "keyboard",
		mode = "released",
		key = lane,
		time = replay.deltaT
	}
	replay.recordedKey[lane] = false

	if replay.eventsToStdout then
		io.stdout:write(string.format("event:keyboard|time:%.6f|mode:released|key:", replay.deltaT), lane, "\n")
	end
end

function replay.recordTouchpressed(id, x, y)
	local randID = "\0\0"
	if id ~= 0 then
		if replay.recordedTouchID[id] then
			log.warningf("replay", "recordTouchpressed: id already registered, %s", tostring(id))
			return
		else
			repeat
				randID = string.char(math.random(0, 255), math.random(0, 255))
			until replay.recordedTouchID[randID] == nil
			replay.recordedTouchID[randID] = id
			replay.recordedTouchID[id] = randID
		end
	end

	replay.recordedEvents[#replay.recordedEvents + 1] = {
		type = "touch",
		mode = "pressed",
		id = randID,
		x = x,
		y = y,
		time = replay.deltaT
	}
	log.debugf("replay", "recordTouchpressed: record pos: %.2fx%.2f, id: %02x%02x", x, y, randID:byte(1, 2))

	if replay.eventsToStdout then
		io.stdout:write(
			string.format("event:touch|time:%.6f|mode:pressed|id:%02x%02x|x:%.4f|y:%.4f",
			replay.deltaT, randID:byte(1, 1), randID:byte(2, 2), x, y
			), "\n"
		)
	end
end

function replay.recordTouchmoved(id, x, y)
	local randID = replay.recordedTouchID[id]
	if randID == nil then
		log.errorf("replay", "recordTouchmoved: id not registered, %s", tostring(id))
		return
	end

	replay.recordedEvents[#replay.recordedEvents + 1] = {
		type = "touch",
		mode = "moved",
		id = randID,
		x = x,
		y = y,
		time = replay.deltaT
	}
	log.debugf("replay", "recordTouchmoved: record pos: %.2fx%.2f, id: %02x%02x", x, y, randID:byte(1, 2))

	if replay.eventsToStdout then
		io.stdout:write(
			string.format("event:touch|time:%.6f|mode:moved|id:%02x%02x|x:%.4f|y:%.4f",
			replay.deltaT, randID:byte(1, 1), randID:byte(2, 2), x, y
			), "\n"
		)
	end
end

function replay.recordTouchreleased(id, x, y)
	local randID = replay.recordedTouchID[id]
	if randID == nil then
		log.errorf("replay", "recordTouchreleased: id not registered, %s", tostring(id))
		return
	end

	replay.recordedEvents[#replay.recordedEvents + 1] = {
		type = "touch",
		mode = "released",
		id = randID,
		x = x,
		y = y,
		time = replay.deltaT
	}
	if id ~= 0 then
		replay.recordedTouchID[id] = nil
		replay.recordedTouchID[randID] = nil
	end
	log.debugf("replay", "recordTouchreleased: record id: %02x%02x", randID:byte(1, 2))

	if replay.eventsToStdout then
		io.stdout:write(
			string.format("event:touch|time:%.6f|mode:released|id:%02x%02x|x:%.4f|y:%.4f",
			replay.deltaT, randID:byte(1, 1), randID:byte(2, 2), x, y
			), "\n"
		)
	end
end

function replay.getEventData()
	return replay.recordedEvents
end

function replay.update(dt)
	replay.deltaT = replay.deltaT + dt

	-- remove line list
	if #replay.replayTouchLine > 0 then
		local length = #replay.replayTouchLine
		local index = 1
		local left = length
		for i = 1, length do
			local l = replay.replayTouchLine[i]
			if l then
				l.time = l.time - dt
				if l.time <= 0 then
					left = left - 1
				else
					replay.replayTouchLine[index] = replay.replayTouchLine[i]
					index = index + 1
				end
			else
				replay.replayTouchLine[index] = replay.replayTouchLine[i]
				index = index + 1
			end
		end

		for i = left + 1, length do
			replay.replayTouchLine[i] = nil
		end
	end

	-- add lines
	for i = 1, #replay.replayEvents do
		local ev = replay.replayEvents[i]
		if replay.deltaT >= ev.time then
			if ev.type == "touch" then
				if ev.mode == "released" then
					replay.replayTouchData[ev.id] = nil
				else
					if ev.mode == "pressed" then
						replay.replayTouchData[ev.id] = {ev.x, ev.y} -- lastx, lasty
					end
					local id = replay.replayTouchData[ev.id]

					-- write line
					replay.replayTouchLine[#replay.replayTouchLine + 1] = {
						x1 = id[1],
						y1 = id[2],
						x2 = ev.x,
						y2 = ev.y,
						time = 1
					}
					id[1], id[2] = ev.x, ev.y
				end
			end
		else
			break
		end
	end
end

function replay.drawTouchLine()
	love.graphics.push("all")
	love.graphics.setLineWidth(8)
	for i = 1, #replay.replayTouchLine do
		local l = replay.replayTouchLine[i]
		love.graphics.setColor(color.compat(255, 232, 232, l.time))
		love.graphics.line(l.x1, l.y1, l.x2, l.y2)
	end
	love.graphics.pop()
end

return replay
