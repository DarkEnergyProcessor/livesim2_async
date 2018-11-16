-- Live Simulator: 2 Replay Loader
-- Part of Live Simulator: 2, released as standalone library
--[[---------------------------------------------------------------------------
-- Copyright (c) 2039 Dark Energy Processor
--
-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not
--    be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source
--    distribution.
--]]---------------------------------------------------------------------------

local lsr = {
	_VERSION = "0.5",
	_LICENSE = "Copyright \169 2039 Dark Energy Processor, licensed under zLib license",
	_AUTHOR = "Dark Energy Processor Corporation"
}
lsr.file = {} -- user-replaceable

-- String to little endian dword (signed)
local function string2dword(str)
	return str:byte(1, 1) + str:byte(2, 2) * 256 + str:byte(3, 3) * 65536 + str:byte(4, 4) * 16777216
end

-- String to little endian dword (unsigned)
local function string2dwordu(str)
	return string2dword(str) % 4294967296
end

-- Double word to little-endian string (unsigned)
local function dwordu2string(num)
	return string.char(
		num % 256,
		math.floor(num / 256) % 256,
		math.floor(num / 65536) % 256,
		math.floor(num / 16777216)
	)
end

-- These float <-> string routines were come from lua-MessagePack
-- which is modified to return string & use little endian order
local function string2float(str)
	local b4, b3, b2, b1 = str:byte(1, 4)
	local sign = 1
	local expo = (b1 % 0x80) * 0x2 + math.floor(b2 / 0x80)
	local mant = ((b2 % 0x80) * 0x100 + b3) * 0x100 + b4
	if b1 > 0x7F then
		sign = -1
	end
	local n
	if mant == 0 and expo == 0 then
		n = sign * 0.0
	elseif expo == 0xFF then
		if mant == 0 then
			n = sign * math.huge
		else
			n = 0.0/0.0
		end
	else
		n = sign * math.ldexp(1.0 + mant / 0x800000, expo - 0x7F)
	end
	return n
end

local function float2string(n)
	local sign = 0
	if n < 0.0 then
		sign = 0x80
		n = -n
	end
	local mant, expo = math.frexp(n)
	if mant ~= mant then
		-- nan
		return string.char(0x00, 0x00, 0x88, 0xFF)
	elseif mant == math.huge or expo > 0x80 then
		if sign == 0 then
			-- inf
			return string.char(0x00, 0x00, 0x80, 0x7F)
		else
			-- -inf
			return string.char(0x00, 0x00, 0x80, 0xFF)
		end
	elseif (mant == 0.0 and expo == 0) or expo < -0x7E then
		-- zero
		return string.char(0x00, 0x00, 0x00, sign)
	else
		expo = expo + 0x7E
		mant = math.floor((mant * 2.0 - 1.0) * math.ldexp(0.5, 24))
		return string.char(
			mant % 0x100,
			math.floor(mant / 0x100) % 0x100,
			(expo % 0x2) * 0x80 + math.floor(mant / 0x10000),
			sign + math.floor(expo / 0x2)
		)
	end
end

-- Filestream wrapper
function lsr.file.openRead(path)
	return io.open(path, "rb")
end

function lsr.file.openWrite(path)
	return io.open(path, "wb")
end

function lsr.file.read(file, bytes)
	return file:read(bytes)
end

function lsr.file.write(file, data)
	return file:write(data)
end

function lsr.file.close(file)
	return file:close()
end

function lsr.loadReplay(path, beatmapHash)
	local file = lsr.file.openRead(path)
	if not(file) then return nil end

	-- check
	if lsr.file.read(file, 4) ~= "ls2r" then return nil end
	local hash = lsr.file.read(file, 16)
	if beatmapHash and hash ~= beatmapHash then return nil end

	-- load it
	local hand = {
		filename = path,
		storyboardSeed = string2dwordu(lsr.file.read(file, 4)),
		score = string2dwordu(lsr.file.read(file, 4)),
		maxCombo = string2dwordu(lsr.file.read(file, 4)),
		totalNotes = string2dwordu(lsr.file.read(file, 4)),
		perfect = string2dwordu(lsr.file.read(file, 4)),
		great = string2dwordu(lsr.file.read(file, 4)),
		good = string2dwordu(lsr.file.read(file, 4)),
		bad = string2dwordu(lsr.file.read(file, 4)),
		miss = string2dwordu(lsr.file.read(file, 4)),
		token = string2dwordu(lsr.file.read(file, 4)),
		tokenAmount = string2dwordu(lsr.file.read(file, 4)),
		perfectNote = string2dwordu(lsr.file.read(file, 4)),
		perfectSwing = string2dwordu(lsr.file.read(file, 4)),
		perfectSimultaneous = string2dwordu(lsr.file.read(file, 4)),
		scorePerTap = string2dwordu(lsr.file.read(file, 4)),
	}
	lsr.file.read(file, 4*12) -- reserved
	local rslo = string2dwordu(lsr.file.read(file, 4))
	local rshi = string2dwordu(lsr.file.read(file, 4))
	if rslo ~= 0 or rshi ~= 0 then
		hand.randomSeed = {rslo, rshi}
	end
	hand.timestamp = string2dwordu(lsr.file.read(file, 4))

	-- accuracy points
	local accuracyLen = string2dwordu(lsr.file.read(file, 4))
	local accuracyData = lsr.file.read(file, accuracyLen)
	hand.accuracy = {}
	for i = 1, accuracyLen do
		hand.accuracy[i] = accuracyData:byte(i, i) / 4
	end

	-- events data
	local eventLen = string2dwordu(lsr.file.read(file, 4))
	hand.events = {}
	for i = 1, eventLen do
		local event = {}
		local eventString = lsr.file.read(file, 16)
		local type = eventString:byte(1, 1)
		local mode = eventString:byte(6, 6)
		event.time = string2float(eventString:sub(2))

		if type == 0 then
			event.type = "keyboard"
			event.mode = mode == 0 and "pressed" or "released"
			event.key = eventString:byte(7, 7)
		elseif type == 1 then
			event.type = "touch"
			event.mode = mode == 0 and "pressed" or (mode == 1 and "moved" or "released")
			event.id = assert(eventString:sub(7, 8))
			event.x = string2float(eventString:sub(9, 12))
			event.y = string2float(eventString:sub(13, 16))
		end

		hand.events[i] = event
	end

	lsr.file.close(file)
	return hand
end

function lsr.saveReplay(path, beatmapHash, seed, noteInfo, accuracyData, events)
	local file = lsr.file.openWrite(path)
	if not(file) then return false end

	-- write header
	lsr.file.write(file,
		"ls2r".. -- signature
		beatmapHash.. -- beatmap hash
		dwordu2string(seed)..
		dwordu2string(noteInfo.score)..
		dwordu2string(noteInfo.maxCombo)..
		dwordu2string(noteInfo.totalNotes)..
		dwordu2string(noteInfo.perfect)..
		dwordu2string(noteInfo.great)..
		dwordu2string(noteInfo.good)..
		dwordu2string(noteInfo.bad)..
		dwordu2string(noteInfo.miss)..
		dwordu2string(noteInfo.token)..
		dwordu2string(noteInfo.tokenAmount)..
		dwordu2string(noteInfo.perfectNote)..
		dwordu2string(noteInfo.perfectSwing)..
		dwordu2string(noteInfo.perfectSimultaneous)..
		dwordu2string(noteInfo.scorePerTap),
		string.rep("\0\0\0\0", 12).. -- reserved
		dwordu2string(noteInfo.randomSeed and noteInfo.randomSeed[1] or 0)..
		dwordu2string(noteInfo.randomSeed and noteInfo.randomSeed[2] or 0)..
		dwordu2string(noteInfo.timestamp or os.time())
	)

	-- accuracy graph
	local sb = {}
	for i = 1, #accuracyData do
		sb[#sb + 1] = string.char(math.floor(accuracyData[i] * 4 + 0.5))
	end
	lsr.file.write(file,
		dwordu2string(#accuracyData)..
		table.concat(sb)..
		dwordu2string(#events)
	)

	-- events
	sb = {}
	for i = 1, #events do
		local event = events[i]
		if event.type == "keyboard" then
			sb[#sb + 1] = string.char(0)
			sb[#sb + 1] = float2string(event.time)
			sb[#sb + 1] = string.char(event.mode == "pressed" and 0 or 1, event.key)
			sb[#sb + 1] = "\0\0\0\0\0\0\0\0\0"
		elseif event.type == "touch" then
			sb[#sb + 1] = string.char(1)
			sb[#sb + 1] = float2string(event.time)
			sb[#sb + 1] = string.char(event.mode == "pressed" and 0 or (event.mode == "moved" and 1 or 2))
			sb[#sb + 1] = event.id:sub(1, 2)
			sb[#sb + 1] = float2string(event.x)
			sb[#sb + 1] = float2string(event.y)
		end

		-- write in 4KB block
		if i % 256 == 1 and #sb > 0 then
			lsr.file.write(file, table.concat(sb))
			for j = #sb, 1, -1 do
				sb[j] = nil
			end
		end
	end

	-- flush
	if #sb > 0 then
		lsr.file.write(file, table.concat(sb))
	end

	lsr.file.close(file)
	return true
end

return lsr
