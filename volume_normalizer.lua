-- Audio volume normalizer, similar to ReplayGain but it's not
-- Part of Live Simulator: 2

local love = love
local _, ffi = pcall(require, "ffi")

if _ == false then
	-- Non-FFI functions
	return function(sd)
		local samples = sd:getSampleCount() * sd:getChannels() - 1
		local sample_data = {}
		local peak = 0
		
		for i = 0, samples do
			local smp = sd:getSample(i)
			
			peak = math.max(peak, math.abs(smp))
			sample_data[i] = smp
		end
		
		print(peak)
		peak = 1 / peak
		print(peak)
		
		for i = 0, samples do
			sd:setSample(i, sample_data[i] * peak)
		end
	end
end

-- FFI functions
return function(sd)
	local samples = sd:getSampleCount() * sd:getChannels() - 1
	local depth = sd:getBitDepth()
	local lower_limits = -2 ^ (depth - 1)
	local upper_limits = 2 ^ (depth - 1) - 1
	local ptr = sd:getPointer()
	local peak = 0
	
	if depth == 8 then
		ptr = ffi.cast("int8_t*", ptr)
	elseif depth == 16 then
		ptr = ffi.cast("int16_t*", ptr)
	end
	
	for i = 0, samples do
		peak = math.max(peak, math.abs(ptr[i]))
	end
	
	peak = upper_limits / peak
	
	for i = 0, samples do
		ptr[i] = math.min(math.max(ptr[i] * peak, lower_limits), upper_limits)
	end
end
