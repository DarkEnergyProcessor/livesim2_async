-- Shelsha, LOVE2D library to load Playground TEXB files
-- Uses LOVE2D function naming case for library
local bit = require("bit")
local ffi = require("ffi")
local lg = require("love.graphics")

local Shelsha = {_internal = {_meta = {}}, _VERSION = "v1.0.0"}
local memreadstream = {}

--------------------------------------
-- LOVE2D version-specific function --
--------------------------------------
local decompress_zlib_func
local make_timg_mesh
local mesh_flush
local is_love_010

do
	local maj, min, rev = love.getVersion()
	is_love_010 = maj == 0 and min >= 10
	
	if not(is_love_010) then
		-- Use external library for deflate
		local deflatelua = require("deflatelua")
		
		function decompress_zlib_func(str)
			local out = {}
			
			deflatelua.inflate_zlib {input = str, output = function(b) out[#out + 1] = string.char(b) end}
			
			return table.concat(out)
		end
		
		function make_timg_mesh(mesh, image)
			return lg.newMesh(mesh, image, "strip")
		end
		
		function mesh_flush() end	-- Not supported
	else
		-- Use love.math.decompress for deflate
		local lm = require("love.math")
		
		function decompress_zlib_func(str)
			return lm.decompress(str, "zlib")
		end
		
		function make_timg_mesh(mesh, image)
			local m = lg.newMesh(mesh, "strip", "static")
			m:setTexture(image)
			
			return m
		end
		
		function mesh_flush(mesh)
			mesh:flush()
		end
	end
end

----------------------
-- Basic conversion --
----------------------
local function string2dwordu(a)
	local str = a:read(4)
	
	return bit.bor(
		bit.lshift(str:byte(), 24),
		bit.lshift(str:sub(2,2):byte(), 16),
		bit.lshift(str:sub(3,3):byte(), 8),
		str:sub(4,4):byte()
	) % 4294967296
end

local function string2wordu(a)
	local str = a:read(2)
	
	return bit.bor(bit.lshift(str:byte(), 8), str:sub(2,2):byte())
end


local function readstring(stream)
	local len = string2wordu(stream)
	local lensub = (len % 2) == 0 and -3 or -2
	
	return stream:read(len):sub(1, lensub)
end

-------------------------------------
-- Pixel format conversion to RGBA --
-------------------------------------
local function luma_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		
		dest[j] = src[i]
		dest[j + 1] = src[i]
		dest[j + 2] = src[i]
		dest[j + 3] = 255
	end
end

local function alpha_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		
		dest[j], dest[j + 1], dest[j + 2] = 0, 0, 0
		dest[j + 3] = src[i]
	end
end

local function lumalpha_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		local k = i * 2
		
		dest[j] = src[k]
		dest[j + 1] = src[k]
		dest[j + 2] = src[k]
		dest[j + 3] = src[k + 1]
	end
end

local function rgb565_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		local k = i * 2
		local pixel = bit.bor(bit.rshift(src[k], 8), src[k + 1])
		local shift
		
		shift = bit.rshift(bit.band(pixel, 0xF800), 8)
		dest[j] = bit.bor(shift, bit.rshift(shift, 5))
		shift = bit.rshift(bit.band(pixel, 0x7E0), 3)
		dest[j + 1] = bit.bor(shift, bit.rshift(shift, 6))
		shift = bit.lshift(bit.band(pixel, 0x1F), 3)
		dest[j + 2] = bit.bor(shift, bit.rshift(shift, 5))
		dest[j + 3] = 255
	end
end

local function rgba5551_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		local k = i * 2
		local pixel = bit.bor(bit.rshift(src[k], 8), src[k + 1])
		local shift
		
		shift = bit.rshift(bit.band(pixel, 0xF800), 8)
		dest[j] = bit.bor(shift, bit.rshift(shift, 5))
		shift = bit.rshift(bit.band(pixel, 0x7C0), 3)
		dest[j + 1] = bit.bor(shift, bit.rshift(shift, 5))
		shift = bit.lshift(bit.band(pixel, 0x3E), 3)
		dest[j + 2] = bit.bor(shift, bit.rshift(shift, 5))
		dest[j + 3] = bit.band(pixel, 1) * 255
	end
end

local function rgba4444_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		local k = i * 2
		local pixel = bit.bor(bit.rshift(src[k], 8), src[k + 1])
		local shift
		
		shift = bit.rshift(bit.band(pixel, 0xF000), 8)
		dest[j] = bit.bor(shift, bit.rshift(shift, 4))
		shift = bit.rshift(bit.band(pixel, 0xF00), 4)
		dest[j + 1] = bit.bor(shift, bit.rshift(shift, 4))
		shift = bit.lshift(bit.band(pixel, 0xF0), 4)
		dest[j + 2] = bit.bor(shift, bit.rshift(shift, 4))
		shift = bit.band(pixel, 0xF)
		dest[j + 3] = bit.bor(shift, bit.lshift(shift, 4))
	end
end

local function rgb_to_rgba(src, len, dest)
	for i = 0, len - 1 do
		local j = i * 4
		local k = i * 3
		
		dest[j] = src[k]
		dest[j + 1] = src[k + 1]
		dest[j + 2] = src[k + 2]
		dest[j] = 255
	end
end

local function rgba_to_rgba(src, len, dest)
	ffi.copy(dest, src, len * 4)
end
---------------------------------------
-- Memory stream code (reading only) --
---------------------------------------
function memreadstream.new(buf)
	local len = #buf + 1
	local buffer = ffi.new("uint8_t["..len.."]", buf)
	local out = {
		pos = 0,
		buflen = len,
		initbuf = buffer,
		curbuf = buffer
	}
	
	return setmetatable(out, {__index = memreadstream})
end

function memreadstream.read(this, bytes)
	local afterpos
	local newbuf
	
	if pos == buflen then return end
	
	afterpos = pos + bytes
	
	if afterpos > buflen then
		bytes = bytes - (afterpos - buflen)
	end
	
	newbuf = ffi.string(curbuf, bytes)
	this.curbuf = this.curbuf + bytes
	this.pos = this.pos + bytes
	
	return newbuf
end

function memreadstream.rewind(this)
	this.curbuf = this.initbuf
	this.pos = 0
end

function memreadstream.seek(this, whence, offset)
	offset = offset or 0
	whence = whence or cur
	
	if whence == "set" then
		assert(offset > 0 and offset <= buflen, "Invalid seek offset")
		
		this.curbuf = this.initbuf + offset
		this.pos = offset
	elseif whence == "cur" then
		local after = this.pos + offset
		
		assert(after > 0 and after <= buflen, "Invalid seek offset")
		
		this.curbuf = this.curbuf + offset
		this.pos = this.pos + offset
	elseif whence == "end" then
		local after = this.buflen + offset
		
		assert(after > 0 and after <= buflen, "Invalid seek offset")
		
		this.curbuf = this.curbuf + this.buflen + offset
		this.pos = this.buflen + offset
	else
		assert(false, "Invalid seek mode")
	end
	
	return this.pos
end

------------------------------
-- Shelsha parsing routines --
------------------------------
function Shelsha._internal.from_stream(stream)
	local out = {}	-- This is actually a metatable
	local texb_size
	local texb_flags
	
	assert(stream:read(4) == "TEXB", "Not a Playground TEXB file")
	texb_size = string2dwordu(stream) + 8
	
	out.timgList = {}
	out.texbName = readstring(stream):sub(2, -6)
	out.width = string2wordu(stream)
	out.height = string2wordu(stream)
	
	texb_flags = string2wordu(stream)
	out.isCompressed = bit.band(texb_flags, 8) == 8
	out.imageFormat = bit.band(texb_flags, 7)
	out.pixelFormat = bit.rshift(bit.band(texb_flags, 192), 6)
	
	out.totalVertexCount = string2wordu(stream)
	out.totalIndexCount = string2wordu(stream)
	out.timgCount = string2wordu(stream)
	
	for i = 1, out.timgCount do
		local timg_data = {}
		local subimgs
		
		assert(stream:read(4) == "TIMG", "Invalid Playground TEXB file")
		stream:read(2)	-- Skip size
		
		timg_data.name = readstring(stream):sub(2, -10)
		subimgs = string2wordu(stream)
		
		if subimgs == 65535 then
			-- Extension. Just skip atm
			local extension_count = string2wordu(stream)
			
			for j = 1, extension_count do
				local a, b = stream:read(2):byte(1, 2)
				
				if b == 0 or b == 1 then
					stream:read(4)
				elseif b == 2 then
					stream:read(string2wordu(stream))
				else
					assert(false, "Undefined TIMG extension")
				end
			end
			
			subimgs = string2wordu(stream)
		end
		
		assert(subimgs == 1, "Only 1 sub image is supported at the moment")
		timg_data.vertexCount = stream:read(1):byte()
		timg_data.indexCount = stream:read(1):byte()
		timg_data.width = string2wordu(stream)
		timg_data.height = string2wordu(stream)
		timg_data.centerX = string2wordu(stream)
		timg_data.centerY = string2wordu(stream)
		timg_data.vertexData = {}
		
		for j = 1, timg_data.vertexCount do
			timg_data.vertexData[j] = {
				string2dwordu(stream) / 65536,	-- X
				string2dwordu(stream) / 65536,	-- Y
				string2dwordu(stream) / 65536,	-- U
				string2dwordu(stream) / 65536,	-- V
			}
		end
		
		timg_data.indexData = {stream:read(timg_data.indexCount):byte(1, timg_data.indexCount)}
		for j = 1, timg_data.indexCount do
			timg_data.indexData[j] = timg_data.indexData[j] + 1	-- 1-based indexing
		end
		
		-- Insert
		out.timgList[i - 1] = timg_data	-- 0-based indexing
		out.timgList[timg_data.name] = timg_data
	end
	
	-- Read TEXB bitmap data
	local bitmap_data_size = texb_size
	local rgba_image_size = out.width * out.height * 4
	local image_buffer = ffi.new(string.format("uint8_t[%d]", rgba_image_size))
	local bitmap_data
	
	if stream.tell then
		bitmap_data_size = bitmap_data_size - stream:tell()
	else
		bitmap_data_size = bitmap_data_size - stream:seek()
	end
	
	if out.isCompressed then
		local compr_type = string2dwordu(stream)
		
		if compr_type == 0 then
			bitmap_data = decompress_zlib_func(stream:read(bitmap_data_size))
		else
			assert(false, "Unknown compression type")
			-- TODO: ETC1, PVR, and such
		end
	else
		bitmap_data = stream:read(bitmap_data_size)
	end
	
	-- Conver pixel format
	Shelsha._internal.pixconv(out, ffi.new("uint8_t[?]", #bitmap_data, bitmap_data), image_buffer)
	
	-- Create image
	bitmap_data = nil
	if not(is_love_010) then
		out.textureBankImage = love.image.newImageData(out.width, out.height)
		
		-- Have to set every pixel, damn it's fucking slow
		for y = 0, out.height - 1 do
			for x = 0, out.width - 1 do
				local index = (y * out.width + x) * 4
				out.textureBankImage:setPixel(
					x, y,
					image_buffer[index],
					image_buffer[index + 1],
					image_buffer[index + 2],
					image_buffer[index + 3]
				)
			end
		end
		
		out.textureBankImage = lg.newImage(out.textureBankImage)
	else
		out.textureBankImage = lg.newImage(love.image.newImageData(
			out.width, out.height, ffi.string(image_buffer, rgba_image_size)
		))
	end
	out.textureBankImage:setWrap("repeat")
	
	-- Set metatable
	out.__index = Shelsha._internal._meta
	
	return setmetatable({}, out)
end

function Shelsha._internal.from_file(filename)
	local manually_opened = false
	local file_handle
	
	if type(filename) == "string" then
		manually_opened = true
		file_handle = assert(love.filesystem.newFile(filename, "r"))
	elseif type(filename) == "userdata" then
		local ftype = filename:type()
		
		if ftype == "FileData" then
			-- Use memory stream
			file_handle = memreadstream.new(ftype:getString())
		elseif ftype == "File" then
			file_handle = filename
		end
	else
		assert(false, "Invalid data specificed")
	end
	
	local res = Shelsha._internal.from_stream(file_handle)
	
	if manually_opened then
		file_handle:close()
	end
	
	return res
end

Shelsha._internal.imgconv_target = {[0] = alpha_to_rgba, luma_to_rgba, lumalpha_to_rgba, rgb_to_rgba, rgba_to_rgba}
function Shelsha._internal.pixconv(this, src, dest)
	if this.pixelFormat == 0 then
		rgb565_to_rgba(src, this.width * this.height, dest)
	elseif this.pixelFormat == 1 then
		rgba5551_to_rgba(src, this.width * this.height, dest)
	elseif this.pixelFormat == 2 then
		rgba4444_to_rgba(src, this.width * this.height, dest)
	elseif this.pixelFormat == 3 then
		Shelsha._internal.imgconv_target[this.imageFormat](src, this.width * this.height, dest)
	else
		assert(false, "Invalid pixel format")
	end
end

---------------------------------------------------
-- Public Shelsha functions (static and methods) --
---------------------------------------------------
function Shelsha.newTextureBank(file)
	if tostring(file):find("file %(") == 1 then
		return Shelsha._internal.from_stream(file)
	else
		return Shelsha._internal.from_file(file)
	end
end

function Shelsha._internal._meta.getImageMesh(this, index)
	this = getmetatable(this)
	local timg_data = assert(this.timgList[index], "Unknown TIMG Index")
	local mesh = make_timg_mesh(timg_data.vertexData, this.textureBankImage)
	
	mesh:setVertexMap(unpack(timg_data.indexData))
	mesh_flush(mesh)
	
	return mesh
end

function Shelsha._internal._meta.getImageDimensions(this, index)
	this = getmetatable(this)
	local timg_data = assert(this.timgList[index], "Unknown TIMG Index")
	
	return timg_data.width, timg_data.height
end

function Shelsha._internal._meta.getImageCenter(this, index)
	this = getmetatable(this)
	local timg_data = assert(this.timgList[index], "Unknown TIMG Index")
	
	return timg_data.centerX, timg_data.centerY
end

function Shelsha._internal._meta.getBankDimensions(this)
	this = getmetatable(this)
	return this.width, this.height
end

function Shelsha._internal._meta.getBankImage(this)
	this = getmetatable(this)
	return this.textureBankImage
end

function Shelsha._internal._meta.getBankImageList(this)
	this = getmetatable(this)
	
	local timg_list = {}
	
	for i = 1, this.timgCount do
		-- Clone
		
		timg_list[i - 1] = {unpack(this.timgList[i - 1])}
		timg_list[i - 1].vertexData = {unpack(timg_list[i - 1].vertexData)}
		timg_list[i - 1].indexData = {unpack(timg_list[i - 1].indexData)}
	end
	
	return timg_list
end

return Shelsha
