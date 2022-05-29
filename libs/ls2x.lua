-- Live Simulator: 2 Extensions Lua binding
-- Part of Live Simulator: 2 Extensions
-- See copyright notice in LS2X main.cpp

local ls2x = {}
local haslib, lib = pcall(require, "ls2xlib")

if not(haslib) then
	-- no features
    io.stderr:write("warning: no features.\n", lib)
	return ls2x
end

assert(lib._VERSION >= "1.0.1", "incompatible ls2xlib loaded")

local ffi = require("ffi")

local function loadFunc(type, ptr)
	return ffi.cast(type, ffi.cast("void**", ptr)[0])
end

-- audiomix
if lib.features.audiomix then
	local audiomix = {}
	ls2x.audiomix = audiomix

	audiomix.resample = loadFunc("void(*)(const short*, short*, size_t, size_t, int)", lib.rawptr.resample)
	audiomix.startSession = loadFunc("bool(*)(float, int, size_t)", lib.rawptr.startAudioMixSession)
	audiomix.mixSample = loadFunc("bool(*)(const short *, size_t, int, float)", lib.rawptr.mixSample)
	audiomix.getSample = loadFunc("void(*)(short *)", lib.rawptr.getAudioMixPointer)
	audiomix.endSession = loadFunc("void(*)()", lib.rawptr.endAudioMixSession)
end

-- fft
if lib.features.fft then
	local fft = {}
	local scalarType = ffi.string(loadFunc("const char*(*)()", lib.rawptr.scalarType)())
	ls2x.fft = fft
	ffi.cdef("typedef "..scalarType.." kiss_fft_scalar;")
	fft.fftr1 = loadFunc("void(*)(const short *, kiss_fft_scalar *, kiss_fft_scalar *, size_t)", lib.rawptr.fftr1)
	fft.fftr2 = loadFunc("void(*)(const short *, kiss_fft_scalar *, size_t, bool)", lib.rawptr.fftr2)
	fft.fftr3 = loadFunc("void(*)(const kiss_fft_scalar *, kiss_fft_scalar *, kiss_fft_scalar *, size_t)", lib.rawptr.fftr3)
	fft.fftr4 = loadFunc("void(*)(const kiss_fft_scalar *, kiss_fft_scalar *, size_t, bool)", lib.rawptr.fftr4)
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
	local loadAudioFile = loadFunc("bool(*)(const char *input, songInformation *info)", lib.rawptr.loadAudioFile)
	local encodingSupported = loadFunc("bool(*)()", lib.rawptr.encodingSupported)

	if encodingSupported() then
		libav.startEncodingSession = loadFunc("bool(*)(const char *, int, int, int)", lib.rawptr.startEncodingSession)
		libav.supplyVideoEncoder = loadFunc("bool(*)(const void *)", lib.rawptr.supplyEncoder)
		libav.endEncodingSession = loadFunc("void(*)()", lib.rawptr.endEncodingSession)
	end
	libav.free = loadFunc("void(*)(void *)", lib.rawptr.av_free)

	function libav.loadAudioFile(path)
		local sInfoP = ffi.new("songInformation[1]") -- FFI-managed object
		local sInfo = sInfoP[0]
		if loadAudioFile(path, sInfoP) then
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
