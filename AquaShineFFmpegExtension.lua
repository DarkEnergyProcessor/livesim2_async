-- AquaShine FFmpeg extension
-- Part of Live Simulator: 2

local AquaShine = ...
local love = love
local _, ffi = pcall(require, "ffi")
local load_ffmpeg_library

-- iOS, or using Lua 5.1 is not supported
if AquaShine.OperatingSystem == "iOS" or _ == false then
	AquaShine.Log("AquaShineFFmpeg", "AquaShine FFmpeg extension is not supported")
	return
elseif AquaShine.OperatingSystem == "Android" then
	-- We have to find our "internal" save directory at first
	-- so we can determine our "lib" dir
	-- This assume external storage mode is enabled
	love.filesystem._setAndroidSaveExternal(false)
	love.filesystem.setIdentity(love.filesystem.getIdentity(), true)
	
	local lib_dir = love.filesystem.getSaveDirectory().."/../../../lib"
	
	-- Reset back to external storage mode
	love.filesystem._setAndroidSaveExternal(false)
	love.filesystem.setIdentity(love.filesystem.getIdentity(), true)
	
	function load_ffmpeg_library(libname, ver)
		AquaShine.Log("AquaShineFFmpeg", "Loading library %s ver %d", libname, ver)
		local _, out = pcall(ffi.load, lib_dir.."/lib"..libname.."-"..ver..".so")
		
		if _ then
			return out
		end
		
		_, out = pcall(ffi.load, libname.."-"..ver)
		
		if _ then
			return out
		end
		
		return nil
	end
else
	-- For desktop, we just need "ffi.load" it
	function load_ffmpeg_library(libname, ver)
		AquaShine.Log("AquaShineFFmpeg", "Loading library %s ver %d", libname, ver)
		local _, out = pcall(ffi.load, libname.."-"..ver)
		
		if _ then
			return out
		end
		
		_, out = pcall(ffi.load, libname)
		
		if _ then
			return out
		end
		
		return nil
	end
end

--------------------------------------
-- AquaShine FFmpeg video extension --
--------------------------------------

local FFmpegExt = {_playing = setmetatable({}, {__mode="v"})}
local FFmpegExtMt = {__index = {}}

-- The order is important, especially in Android
local avutil = load_ffmpeg_library("avutil", 55)
local swresample = load_ffmpeg_library("swresample", 2)
local avcodec = load_ffmpeg_library("avcodec", 57)
local avformat = load_ffmpeg_library("avformat", 57)
local swscale = load_ffmpeg_library("swscale", 4)

if not(avutil and swresample and avcodec and avformat and swscale) then
	-- FFmpeg library not found/can't be loaded
	AquaShine.Log("AquaShineFFmpeg", "FFmpeg library not found/can't be loaded")
	return
end

AquaShine.Log("AquaShineFFmpeg", "Loading include files", libname, ver)

local include = love.math.decompress(love.filesystem.read("ffmpeg_include_compressed"), "zlib")

ffi.cdef(include)
ffi.cdef[[
int av_image_fill_arrays(uint8_t *dst_data[4], int dst_linesize[4],
                         const uint8_t *src,
                         enum AVPixelFormat pix_fmt, int width, int height, int align);
int av_opt_set_int     (void *obj, const char *name, int64_t     val, int search_flags);
int av_opt_set_sample_fmt(void *obj, const char *name, enum AVSampleFormat fmt, int search_flags);

typedef struct SwrContext SwrContext;
struct SwrContext *swr_alloc(void);
struct SwrContext *swr_alloc_set_opts(struct SwrContext *s,
                                      int64_t out_ch_layout, enum AVSampleFormat out_sample_fmt, int out_sample_rate,
                                      int64_t  in_ch_layout, enum AVSampleFormat  in_sample_fmt, int  in_sample_rate,
                                      int log_offset, void *log_ctx);
int swr_init(struct SwrContext *s);
void swr_free(struct SwrContext **s);
int swr_convert(struct SwrContext *s, uint8_t **out, int out_count,
                                const uint8_t **in , int in_count);
int64_t swr_get_delay(struct SwrContext *s, int64_t base);

typedef struct AquaShineFFmpegData
{
	AVIOContext* IOContext;
	AVFormatContext* FmtContext;
	AVCodecContext* CodecContext;
	AVFrame* FrameVideo;
	AVFrame* FrameRGB;
	struct SwsContext* SwsCtx;
} AquaShineFFmpegData;
]]
avformat.av_register_all()
avcodec.avcodec_register_all()
AquaShine.Log("AquaShineFFmpeg", "FFmpeg initialized", libname, ver)

local read_callback = ffi.typeof("int(*)(void *opaque, uint8_t *buf, int buf_size)")
local function make_read_callback(file)
	local x = function(_unused, buf, buf_size)
		local readed, size = file:read(buf_size)
		
		ffi.copy(buf, readed, size)
		return size
	end
	local y = ffi.cast(read_callback, x)
	
	jit.off(x)
	return y, x
end

local seek_callback = ffi.typeof("int64_t(*)(void *opaque, int64_t offset, int whence)")
local function make_seek_callback(file)
	local filestreamsize = nil 
	local x = function(_unused, pos, whence)
		local success = false
		if whence == 0x10000 then
			-- AVSEEK_SIZE
			if not(filestreamsize) then
				filestreamsize = file:getSize()
			end
			
			return filestreamsize
		elseif whence == 0 then
			-- SEEK_SET
			success = file:seek(tonumber(pos))
		elseif whence == 1 then
			-- SEEK_CUR
			success = file:seek(tonumber(pos) + file:tell())
		elseif whence == 2 then
			-- SEEK_END
			if not(filestreamsize) then
				filestreamsize = file:getSize()
			end
			
			success = file:seek(tonumber(pos) + filestreamsize)
		end
		
		return success and file:tell() or -1LL
	end
	local y = ffi.cast(seek_callback, x)
	
	jit.off(x)
	return y, x
end

local function __free_frame(frame)
	local x = ffi.new("AVFrame*[1]")
	x[0] = frame
	
	avutil.av_frame_free(x)
end

-- Used to free associated resource a.k.a destructor
local function ffmpeg_data_cleanup(this)
	AquaShine.Log("AquaShineFFmpeg", "Cleanup %s", tostring(this))
	
	if this.SwsCtx ~= nil then
		swscale.sws_freeContext(this.SwsCtx)
	end
	
	if this.FrameVideo ~= nil then
		__free_frame(this.FrameVideo)
	end
	
	if this.FrameRGB ~= nil then
		__free_frame(this.FrameRGB)
	end
	
	if this.CodecContext ~= nil then
		avcodec.avcodec_close(this.CodecContext)
	end
	
	if this.FmtContext ~= nil then
		local x = ffi.new("AVFormatContext*[1]")
		x[0] = this.FmtContext
		
		avformat.avformat_close_input(x)
	end
	
	if this.IOContext ~= nil then
		avutil.av_free(this.IOContext)
	end
	
	return avutil.av_free(this)
end

--! @brief Load audio in the specificed path with FFmpeg
--! @param path The video path
--! @returns AquaShineVideo object
--! @note It doesn't load the audio
function FFmpegExt.LoadVideo(path)
	local this = {}
	
	this.FFmpegData = ffi.gc(
		ffi.cast(
			"AquaShineFFmpegData*",
			avutil.av_mallocz(ffi.sizeof("AquaShineFFmpegData"))
		),
		ffmpeg_data_cleanup
	)
	
	AquaShine.Log("AquaShineFFmpeg", "LoadVideo %s", path)
	-- Load the file with love.filesystem API
	this.FileStream = assert(love.filesystem.newFile(path, "r"))
	AquaShine.Log("AquaShineFFmpeg", "LoadVideo %s stream opened", path)
	this.ReadType, this.ReadFunc = make_read_callback(this.FileStream)
	this.SeekType, this.SeekFunc = make_seek_callback(this.FileStream)
	
	-- Create AVIOContext
	this.FFmpegData.IOContext = avformat.avio_alloc_context(
		nil, 0, 0, nil,
		this.ReadType, nil, this.SeekType
	)
	
	-- Allocate AVFormatContext
	local tempfmtctx = ffi.new("AVFormatContext*[1]")
	tempfmtctx[0] = avformat.avformat_alloc_context()
	tempfmtctx[0].pb = this.FFmpegData.IOContext
	
	-- Open input
	if avformat.avformat_open_input(tempfmtctx, path, nil, nil) < 0 then
		this.ReadType:free()
		this.SeekType:free()
		assert(false, "Cannot open input file")
	end
	this.FFmpegData.FmtContext = tempfmtctx[0]
	
	-- Find video stream
	if avformat.avformat_find_stream_info(tempfmtctx[0], nil) < 0 then
		this.ReadType:free()
		this.SeekType:free()
		assert(false, "Failed to determine stream info")
	end
	for i = 1, tempfmtctx[0].nb_streams do
		local codec_type = tempfmtctx[0].streams[i - 1].codec.codec_type
		
		if codec_type == "AVMEDIA_TYPE_VIDEO" then
			this.VideoStreamIndex = i - 1
			break
		end
	end
	if not(this.VideoStreamIndex) then
		this.ReadType:free()
		this.SeekType:free()
		assert(false, "Video stream not found")
	end
	local videostream = tempfmtctx[0].streams[this.VideoStreamIndex]
	
	this.ReadType:free()
	this.SeekType:free()
	
	-- Find video decoder
	local codec = avcodec.avcodec_find_decoder(videostream.codec.codec_id)
	assert(codec ~= nil, "Codec not found")
	
	-- Create CodecContext
	this.FFmpegData.CodecContext = avcodec.avcodec_alloc_context3(codec)
	assert(avcodec.avcodec_copy_context(this.FFmpegData.CodecContext, videostream.codec) >= 0, "Failed to copy context")
	assert(avcodec.avcodec_open2(this.FFmpegData.CodecContext, codec, nil) >= 0, "Cannot open codec")
	
	-- Init frame
	this.FFmpegData.FrameVideo = avutil.av_frame_alloc()
	assert(this.FFmpegData.FrameVideo ~= nil, "Failed to initialize frame")
	this.FFmpegData.FrameRGB = avutil.av_frame_alloc()
	assert(this.FFmpegData.FrameRGB ~= nil, "Failed to initialize RGB frame")
	
	-- We don't have to calculate the memory size with FFmpeg API. RGBA is always 4wh
	-- And ImageData will do the memory allocation automatically with just width and height information
	this.ImageData = love.image.newImageData(this.FFmpegData.CodecContext.width, this.FFmpegData.CodecContext.height)
	this.Image = love.graphics.newImage(this.ImageData)
	
	-- We don't have to allocate another new memory to store the RGBA video data
	-- Just pass the ImageData pointer directly to FFmpeg and we're good
	local imagedataptr = ffi.cast("uint8_t*", this.ImageData:getPointer())
	avutil.av_image_fill_arrays(
		this.FFmpegData.FrameRGB.data,
		this.FFmpegData.FrameRGB.linesize,
		imagedataptr,
		"AV_PIX_FMT_RGBA",
		this.FFmpegData.CodecContext.width,
		this.FFmpegData.CodecContext.height, 1
	)
	
	-- Create our SwsContext
	this.FFmpegData.SwsCtx = swscale.sws_getContext(
		this.FFmpegData.CodecContext.width,
		this.FFmpegData.CodecContext.height,
		this.FFmpegData.CodecContext.pix_fmt,
		this.FFmpegData.CodecContext.width,
		this.FFmpegData.CodecContext.height,
		"AV_PIX_FMT_RGBA",		-- Don't forget that ImageData expects RGBA values
		2, 						-- SWS_BILINEAR
		nil, nil, nil
	)
	
	-- Post init
	this.CurrentTimer = 0
	this.Playing = false
	this.TimeBase = videostream.time_base
	
	-- Ready to use
	return (setmetatable(this, FFmpegExtMt))
end

-- Reusable object
local packet = ffi.new("AVPacket[1]")
local framefinished = ffi.new("int[1]")
function FFmpegExt.Update(deltaT)
	-- deltaT in seconds
	for i = 1, #FFmpegExt._playing do
		local obj = FFmpegExt._playing[i]
		local data = obj.FFmpegData
		obj.CurrentTimer = obj.CurrentTimer + deltaT
		
		while obj.PresentationTS == nil or obj.CurrentTimer >= obj.PresentationTS do
			framefinished[0] = 0
			
			-- Read the video frame
			local readframe = avformat.av_read_frame(data.FmtContext, packet)
			while readframe >= 0 do
				if packet[0].stream_index == obj.VideoStreamIndex then
					-- Get presentation timestamp
					local effortts = avutil.av_frame_get_best_effort_timestamp(data.FrameVideo)
					
					if effortts ~= -9223372036854775808LL then
						obj.PresentationTS = tonumber(effortts - data.FmtContext.start_time) / obj.TimeBase.den * obj.TimeBase.num
					end
					
					-- Decode
					avcodec.avcodec_decode_video2(data.CodecContext, data.FrameVideo, framefinished, packet)
				end
				
				avcodec.av_free_packet(packet)
				
				-- If the frame finished, convert the pixel data directly to LOVE2D ImageData memory
				if framefinished[0] > 0 then
					swscale.sws_scale(data.SwsCtx,
						ffi.cast("const uint8_t *const *", data.FrameVideo.data),
						data.FrameVideo.linesize, 0, data.CodecContext.height,
						data.FrameRGB.data, data.FrameRGB.linesize
					)
					
					break
				end
				
				readframe = avformat.av_read_frame(data.FmtContext, packet)
			end
			
			if readframe >= 0 then
				-- Previous call should return 0 or higher. Refresh the image
				obj.Image:refresh()
			else
				-- We reached EOF or error occured
				-- "pause" method do some things to prevent memory leaks
				obj:pause()
				break
			end
		end
	end
end

-----------------------
-- Metatable methods --
-----------------------

--! @brief Play video
--! @param this AquaShineVideo object
function FFmpegExtMt.__index.play(this)
	if this.Playing then return end
	
	-- Set up callback
	this.ReadType = read_callback(this.ReadFunc)
	this.SeekType = seek_callback(this.SeekFunc)
	this.FFmpegData.IOContext.read_packet = this.ReadType
	this.FFmpegData.IOContext.seek = this.SeekType
	this.Playing = true
	jit.off(this.ReadFunc)
	jit.off(this.SeekFunc)
	
	-- Insert to playing queue
	FFmpegExt._playing[#FFmpegExt._playing + 1] = this
end

--! @brief Pause video
--! @param this AquaShineVideo object
function FFmpegExtMt.__index.pause(this)
	if this.Playing == false then return end
	
	for i = 1, #FFmpegExt._playing do
		if FFmpegExt._playing[i] == this then
			this.Playing = false
			table.remove(FFmpegExt._playing, i)
			
			-- Cleanup callback
			this.ReadType:free()
			this.SeekType:free()
			
			return
		end
	end
end

--! @brief Rewind video
--! @param this AquaShineVideo object
function FFmpegExtMt.__index.rewind(this)
	assert(avformat.av_seek_frame(this.FFmpegData.FmtContext, -1, 0LL, 1) >= 0, "Failed to rewind")
end

function FFmpegExtMt.__index.isPlaying(this)
	return this.Playing
end

-- Dimensions
function FFmpegExtMt.__index.getDimensions(this)
	return this.FFmpegData.CodecContext.width, this.FFmpegData.CodecContext.height
end

function FFmpegExtMt.__index.getWidth(this)
	return this.FFmpegData.CodecContext.width
end

function FFmpegExtMt.__index.getHeight(this)
	return this.FFmpegData.CodecContext.height
end

-- Filters
function FFmpegExtMt.__index.getFilter(this)
	return this.Image:getFilter()
end

function FFmpegExtMt.__index.setFilter(this, min, mag, anis)
	return this.Image:setFilter(min, mag, anis)
end

-- Utils
function FFmpegExtMt.__index.getSource()
	return nil
end

function FFmpegExtMt.__index.type()
	return "AquaShineVideo"
end

--------------------------------------
-- AquaShine FFmpeg audio extension --
--------------------------------------
function FFmpegExt.LoadAudio(path)
	-- Load the file with love.filesystem API
	local filestream = assert(love.filesystem.newFile(path, "r"))
	local readtype, readfunc = make_read_callback(filestream, true)
	local seektype, seekfunc = make_seek_callback(filestream, true)
	
	-- Create AVIOContext
	local IOContext = avformat.avio_alloc_context(
		nil, 0, 0, nil,
		readtype, nil, seektype
	)
	
	-- Allocate AVFormatContext
	local tempfmtctx = ffi.new("AVFormatContext*[1]")
	tempfmtctx[0] = avformat.avformat_alloc_context()
	tempfmtctx[0].pb = IOContext
	
	-- Open input
	if avformat.avformat_open_input(tempfmtctx, path, nil, nil) < 0 then
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		assert(false, "Cannot open input file")
	end
	
	-- Find audio stream
	local audiostreamidx
	
	if avformat.avformat_find_stream_info(tempfmtctx[0], nil) < 0 then
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		assert(false, "Failed to determine stream info")
	end
	
	for i = 1, tempfmtctx[0].nb_streams do
		local codec_type = tempfmtctx[0].streams[i - 1].codec.codec_type
		
		if codec_type == "AVMEDIA_TYPE_AUDIO" then
			audiostreamidx = i - 1
			break
		end
	end
	
	if not(audiostreamidx) then
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		assert(false, "Audio stream not found")
	end
	
	local audiostream = tempfmtctx[0].streams[audiostreamidx]
	
	-- Find decoder
	local codec = avcodec.avcodec_find_decoder(audiostream.codec.codec_id)
	if codec == nil then
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		assert(false, "Codec not found")
	end
	
	-- Create CodecContext
	local CodecContext = avcodec.avcodec_alloc_context3(codec)
	
	if avcodec.avcodec_copy_context(CodecContext, audiostream.codec) < 0 then
		avcodec.avcodec_close(CodecContext)
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		
		assert(false, "Failed to copy context")
	end
	
	if avcodec.avcodec_open2(CodecContext, codec, nil) < 0 then
		avcodec.avcodec_close(CodecContext)
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		
		assert(false, "Cannot open codec")
	end
	
	-- Create SwrContext
	local SwrCtx = ffi.new("SwrContext*[1]")
	SwrCtx[0] = swresample.swr_alloc_set_opts(nil,
		3,
		"AV_SAMPLE_FMT_S16",
		44100,
		audiostream.codec.channel_layout,
		audiostream.codec.sample_fmt,
		audiostream.codec.sample_rate,
		0, nil
	)
	
	if swresample.swr_init(SwrCtx[0]) < 0 then
		avcodec.avcodec_close(CodecContext)
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		
		assert(false, "Failed to initialize swresample")
	end
	
	-- Create new SoundData
	local SampleCountLove2D = math.ceil((tonumber(tempfmtctx[0].duration) / 1000000 + 1) * 44100)
	local SoundData = love.sound.newSoundData(SampleCountLove2D, 44100, 16, 2)
	local SoundDataPointer = ffi.cast("uint8_t*", SoundData:getPointer())
	local AudioFrame = avutil.av_frame_alloc()
	
	if AudioFrame == nil then
		swresample.swr_free(SwrCtx)
		avcodec.avcodec_close(CodecContext)
		avformat.avformat_close_input(tempfmtctx)
		avutil.av_free(IOContext)
		readtype:free()
		seektype:free()
		filestream:close()
		
		assert(false, "Failed to initialize frame")
	end
	
	local outbuf = ffi.new("uint8_t*[2]")
	local out_size = SampleCountLove2D
	outbuf[0] = SoundDataPointer
	
	-- Decode audio
	local readframe = avformat.av_read_frame(tempfmtctx[0], packet)
	while readframe >= 0 do
		if packet[0].stream_index == audiostreamidx then
			local decodelen = avcodec.avcodec_decode_audio4(CodecContext, AudioFrame, framefinished, packet)
			
			if decodelen < 0 then
				__free_frame(AudioFrame)
				avcodec.av_free_packet(packet)
				swresample.swr_free(SwrCtx)
				avcodec.avcodec_close(CodecContext)
				avformat.avformat_close_input(tempfmtctx)
				avutil.av_free(IOContext)
				readtype:free()
				seektype:free()
				filestream:close()
				
				assert(false, "Audio decoding error")
			end
			
			if framefinished[0] > 0 then
				local samples = swresample.swr_convert(SwrCtx[0],
					outbuf, AudioFrame.nb_samples,
					ffi.cast("const uint8_t**", AudioFrame.extended_data),
					AudioFrame.nb_samples
				)
				
				if samples < 0 then
					__free_frame(AudioFrame)
					avcodec.av_free_packet(packet)
					swresample.swr_free(SwrCtx)
					avcodec.avcodec_close(CodecContext)
					avformat.avformat_close_input(tempfmtctx)
					avutil.av_free(IOContext)
					readtype:free()
					seektype:free()
					filestream:close()
					
					assert(false, "Resample error")
				end
				
				outbuf[0] = outbuf[0] + samples * 4
				out_size = out_size - samples
			end
		end
		
		avcodec.av_free_packet(packet)
		readframe = avformat.av_read_frame(tempfmtctx[0], packet)
	end
	
	-- Flush buffer
	swresample.swr_convert(SwrCtx[0], outbuf, out_size, nil, 0)
	
	-- Free
	__free_frame(AudioFrame)
	avcodec.av_free_packet(packet)
	swresample.swr_free(SwrCtx)
	avcodec.avcodec_close(CodecContext)
	avformat.avformat_close_input(tempfmtctx)
	avutil.av_free(IOContext)
	readtype:free()
	seektype:free()
	filestream:close()
	
	return SoundData
end

-- Inject our proxy to love.graphics.draw
local graphics_draw = love.graphics.draw
function love.graphics.draw(obj, ...)
	if type(obj) == "table" and obj.FFmpegData then
		obj = obj.Image
	end
	
	graphics_draw(obj, ...)
end

-- Set the AquaShine variable
AquaShine.FFmpegExt = FFmpegExt
