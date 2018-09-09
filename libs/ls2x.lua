-- Live Simulator: 2 Extensions Lua binding
-- Part of Live Simulator: 2 Extensions
-- See copyright notice in LS2X main.cpp

local ls2x = {}
local haslib, lib = pcall(require, "ls2xlib")

if not(haslib) then
	-- no features
	return ls2x
end

local ffi = require("ffi")

-- audiomix
if lib.features.audiomix then
	local audiomix = {}
	ls2x.audiomix = audiomix

	audiomix.resample = ffi.cast("void(*)(const short*, short*, size_t, size_t, int)", lib.rawptr.resample)
	audiomix.startSession = ffi.cast("bool(*)(float, int, size_t)", lib.rawptr.startAudioMixSession)
	audiomix.mixSample = ffi.cast("bool(*)(const short *, size_t, int, float)", lib.rawptr.mixSample)
	audiomix.getSample = ffi.cast("void(*)(short *)", lib.rawptr.getAudioMixPointer)
	audiomix.endSession = ffi.cast("void(*)()", lib.rawptr.endAudioMixSession)
end

-- fft
if lib.features.fft then
	local fft = {}
	local scalarType = ffi.string(ffi.cast("const char*(*)()", lib.rawptr.scalarType)())
	ls2x.fft = fft
	ffi.cdef("typedef "..scalarType.." kiss_fft_scalar;")
	fft.fftr1 = ffi.cast("void(*)(const short *, kiss_fft_scalar *, kiss_fft_scalar *, size_t)", lib.rawptr.fftr1)
	fft.fftr2 = ffi.cast("void(*)(const short *, kiss_fft_scalar *, size_t, bool)", lib.rawptr.fftr2)
end

-- libav
if lib.features.libav then
	local libav = {}
	ls2x.libav = libav

	ffi.cdef [[
		typedef struct songMetadata
		{
			size_t keySize;
			char *key;
			size_t valueSize;
			char *value;
		} songMetadata;
		typedef struct songInformation
		{
			size_t sampleRate;
			size_t sampleCount;
			short *samples;
			size_t metadataCount;
			songMetadata *metadata;
			size_t coverArtWidth, coverArtHeight;
			char *coverArt;
		} songInformation;
	]]
	local loadAudioFile = ffi.cast("bool(*)(const char *input, songInformation *info)", lib.rawptr.loadAudioFile)
	
	libav.startEncodingSession = ffi.cast("bool(*)(const char *, int, int, int)", lib.rawptr.startEncodingSession)
	libav.supplyVideoEncoder = ffi.cast("bool(*)(const void *)", lib.rawptr.supplyEncoder)
	libav.endEncodingSession = ffi.cast("void(*)()", lib.rawptr.endEncodingSession)
	libav.free = ffi.cast("void(*)(void *)", lib.rawptr.av_free)

	function libav.loadAudioFile(path)
		local sInfoP = ffi.new("songInformation[1]") -- FFI-managed object
		local sInfo = sInfoP[0]
		if loadAudioFile(path, sInfoP) then
			local meta = {}
			local info = {
				sampleRate = sInfo.sampleRate,
				sampleCount = sInfo.sampleCount,
				samples = sInfo.samples,
				metadata = {},
			}
			if sInfo.coverArt ~= nil then
				info.coverArt = {
					width = sInfo.coverArtWidth,
					height = sInfo.coverArtHeight,
					data = sInfo.coverArt
				}
			end
			if sInfo.metadataCount > 0 then 
				for i = 1, tonumber(sInfo.metadataCount) do
					local dict = sInfo.metadata[i-1]
					local k = ffi.string(dict.key, dict.keySize)
					local v = ffi.string(dict.value, dict.valueSize)
					info.metadata[k] = v
					libav.free(dict.key)
					libav.free(dict.value)
				end
				libav.free(sInfo.metadata)
			end
			
			return info
		else
			return nil
		end
	end
end

return ls2x
