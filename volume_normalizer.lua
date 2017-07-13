-- Audio volume normalizer, similar to ReplayGain but it's not
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = love
local _, ffi = pcall(require, "ffi")
local Cores = love.system.getProcessorCount()
local Channel = love.thread.newChannel()
local PeakDetectCode
local NormalizeCode

local function splitIntoParts(whole, parts)
	local arr = {}
	local remain = whole
	local partsLeft = parts

	while partsLeft > 0 do
		local size = math.floor((remain + partsLeft - 1) / partsLeft)
		arr[#arr + 1] = size
		remain = remain - size
		partsLeft = partsLeft - 1
	end

	return arr
end

local function run_parallel(code, arglist)
	local threadlist = {}
	
	for i = 1, Cores do
		threadlist[i] = love.thread.newThread(code)
	end
	
	for i = 1, Cores do
		threadlist[i]:start(unpack(arglist[i]))
	end
	
	for i = 1, Cores do
		threadlist[i]:wait()
	end
end

if _ == false then
	-- Non-FFI functions
	PeakDetectCode = [[
local ls = require("love.sound")
local getSample = debug.getregistry().SoundData.getSample
local sd, start, stop, chnl = ...
local peak = 0

for i = start, stop do
	peak = math.max(peak, math.abs(getSample(sd, i)))
end

chnl:push(peak)
]]
	NormalizeCode = [[
local ls = require("love.sound")
local SoundData = debug.getregistry().SoundData
local sd, start, stop, peak = ...

if peak >= 1/32767 then return end

for i = start, stop do
	SoundData.setSample(sd, i, SoundData.getSample(sd, i) * peak)
end
]]
	return function(sd)
		local samples_per_thread = splitIntoParts(sd:getSampleCount() * sd:getChannels(), Cores)
		local thread_arg = {}
		local parts = 0
		local peak = 0
		
		for i = 1, Cores do
			thread_arg[i] = {sd, parts, parts + samples_per_thread[i] - 1, Channel}
			parts = parts + samples_per_thread[i]
		end
		
		run_parallel(PeakDetectCode, thread_arg)
		
		for i = 1, Cores do
			peak = math.max(peak, Channel:pop())
		end
		
		peak = 1 / peak
		
		for i = 1, Cores do
			thread_arg[i][4] = peak
		end
		
		run_parallel(NormalizeCode, thread_arg)
	end
end

PeakDetectCode = [[
local ffi = require("ffi")
local ptr, dttp, start, stop, chnl, tid = ...
local peak = 0

ptr = ffi.cast(dttp, ptr)

for i = start, stop do
	peak = math.max(peak, math.abs(ptr[i]))
end

chnl:push(peak)
]]
NormalizeCode = [[
local ffi = require("ffi")
local ptr, dttp, start, stop, peak, upl, lowl = ...

ptr = ffi.cast(dttp, ptr)

for i = start, stop do
	ptr[i] = math.min(math.max(ptr[i] * peak, lowl), upl)
end
]]

-- FFI functions
return function(sd)
	local samples_per_thread = splitIntoParts(sd:getSampleCount() * sd:getChannels(), Cores)
	local depth = sd:getBitDepth()
	local lower_limits = -2 ^ (depth - 1)
	local upper_limits = 2 ^ (depth - 1) - 1
	local ptr = sd:getPointer()
	local dttp
	local thread_arg = {}
	local parts = 0
	local peak = 0
	
	if depth == 8 then
		dttp = "int8_t*"
	elseif depth == 16 then
		dttp = "int16_t*"
	end
	
	for i = 1, Cores do
		local temp = {}
		
		temp[1] = ptr
		temp[2] = dttp
		temp[3] = parts
		temp[4] = parts + samples_per_thread[i] - 1
		temp[5] = Channel
		temp[6] = i
		
		thread_arg[i] = temp
		parts = parts + samples_per_thread[i]
	end
	
	run_parallel(PeakDetectCode, thread_arg)
	
	for i = 1, Cores do
		peak = math.max(peak, Channel:pop())
	end
	
	peak = upper_limits / peak
	
	for i = 1, Cores do
		local temp = thread_arg[i]
		
		temp[5] = peak
		temp[6] = upper_limits
		temp[7] = lower_limits
	end
	
	run_parallel(NormalizeCode, thread_arg)
end
