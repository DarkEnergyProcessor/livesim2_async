-- OpenAL Audio Render Hijack
-- Part of Live Simulator: 2, can be used as standalone library
--[[---------------------------------------------------------------------------
-- Copyright (c) 2021 Miku AuahDark
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.
--]]---------------------------------------------------------------------------

local AudioRender = {}
AudioRender.success = false

---@class OpenAL32
---@field public alcOpenDevice fun(device: string): ffi.cdata*
---@field public alcIsExtensionPresent fun(device: ffi.cdata*, extension: string): boolean
---@field public alcCreateContext fun(device: ffi.cdata*, attrs: integer[]): ffi.cdata*
---@field public alcGetProcAddress fun(device: ffi.cdata*, proc: string): ffi.cdata*
AudioRender.OpenAL32 = nil

local iscdef = false
local updateBuffer = {0, nil}
local VALID_ARCH = {
	x64 = true,
	arm64 = false
}

local CHANLOOKUP = {
	mono = 0x1500,
	stereo = 0x1501,
	quad = 0x1503,
	["5.1"] = 0x1504,
	["6.1"] = 0x1505,
	["7.1"] = 0x1506
}

local CHANLOOKUPSIZE = {
	mono = 1,
	stereo = 2,
	quad = 4,
	["5.1"] = 6,
	["6.1"] = 7,
	["7.1"] = 8
}

local DTYPELOOKUP = {
	byte = 0x1401,
	short = 0x1402,
	int = 0x1404,
	float = 0x1406
}

local DTYPEFFILOOKUP = {
	byte = "uint8_t[?]",
	short = "int16_t[?]",
	int = "int32_t[?]",
	float = "float[?]"
}

local CodeJumper = {}
function CodeJumper.init()
	local ffi = AudioRender.ffi

	if ffi.os == "Windows" then
		ffi.cdef[[
			bool __stdcall VirtualProtect(void *addr, size_t length, uint32_t prot, uint32_t *oldprot);
			bool __stdcall FlushInstructionCache (void *process, void *addr, size_t size);
		]]

		local uint32a = ffi.new("uint32_t[1]")

		function CodeJumper.patch(addr, newaddr)
			addr = ffi.cast("void*", addr)
			local instruction = CodeJumper.encodeJump(newaddr)

			if ffi.C.VirtualProtect(addr, #instruction, 0x4, uint32a) then
				local oldProt = uint32a[0]
				local old = ffi.string(addr, #instruction)
				ffi.copy(addr, instruction, #instruction)
				assert(ffi.C.VirtualProtect(addr, #instruction, oldProt, uint32a))
				ffi.C.FlushInstructionCache(ffi.cast("void*", -1), addr, #instruction)

				return {address = addr, old = old}
			end

			return nil
		end

		function CodeJumper.unpatch(obj)
			assert(ffi.C.VirtualProtect(obj.address, #obj.old, 0x4, uint32a))
			local oldProt = uint32a[0]
			ffi.copy(obj.address, obj.old, #obj.old)
			assert(ffi.C.VirtualProtect(obj.address, #obj.old, oldProt, uint32a))
			ffi.C.FlushInstructionCache(ffi.cast("void*", -1), obj.address, #obj.old)
		end
	elseif ffi.os == "Linux" then
		ffi.cdef[[
			int mprotect(void *addr, size_t len, int prot);
			int getpagesize();
		]]

		local PAGE_SIZE = ffi.C.getpagesize()

		local function alignMemory(addr)
			local mem = ffi.cast("size_t", addr)
			local remainder = mem % PAGE_SIZE

			if remainder == 0 then
				return addr
			end

			return ffi.cast("void*", mem - remainder)
		end

		local function nearestMultipleOfPage(n)
			return math.ceil(n / PAGE_SIZE) * PAGE_SIZE
		end

		function CodeJumper.patch(addr, newaddr)
			addr = ffi.cast("void*", addr)
			local aligned = alignMemory(addr)
			local mem = ffi.cast("void*", aligned)
			local instruction = CodeJumper.encodeJump(newaddr)
			local patchLen = nearestMultipleOfPage(#instruction)

			if ffi.C.mprotect(mem, patchLen, 0x1 + 0x2) == 0 then
				local old = ffi.string(addr, #instruction)
				ffi.copy(addr, instruction, #instruction)
				-- FIXME: Probably use PAGE_EXEC only in Android?
				assert(ffi.C.mprotect(mem, patchLen, 0x1 + 0x4) == 0)

				return {base = mem, address = addr, old = old, size = patchLen}
			end

			return nil
		end

		function CodeJumper.unpatch(obj)
			assert(ffi.C.mprotect(obj.base, obj.size, 0x1 + 0x2) == 0)
			ffi.copy(obj.address, obj.old, #obj.old)
			assert(ffi.C.mprotect(obj.base, obj.size, 0x1 + 0x4) == 0)
		end
	else
		error("unsupported platform")
	end

	if ffi.arch == "x64" then
		local int64a = ffi.new("uint64_t[1]")

		function CodeJumper.encodeJump(newaddr)
			int64a[0] = ffi.cast("uint64_t", newaddr)
			return
				-- movabs rax, newaddr
				string.char(0x48, 0xb8)..ffi.string(int64a, 8)..
				-- jmp rax
				string.char(0xff, 0xe0)
		end
	elseif ffi.arch == "arm64" then
		error("unsupported architecture (todo arm64)")
		local int32a = ffi.new("uint32_t[5]")
		function CodeJumper.encodeJump(newaddr)
			local addr = ffi.cast("uint64_t", newaddr)
			local addrhi, addrlo = tonumber(addr / 4294967296), tonumber(addr % 4294967296)
			local addr0 = addrlo % 65536
			local addr1 = math.floor(addrlo / 65536)
			local addr2 = addrhi % 65536
			local addr3 = math.floor(addrhi / 65536)

			int32a[0] = bit.band(int32a)
			return ""
		end
	else
		error("unsupported architecture")
	end
end

-- Initialize OpenAL alcOpenDevice hijack for loopback rendering.
-- See https://openal-soft.org/openal-extensions/SOFT_loopback.txt
---@param freq integer
---@param channel '"mono"' | '"stereo"' | '"quad"' | '"5.1"' | '"6.1"' | '"7.1"'
---@param dtype '"byte"' | '"short"' | '"int"' | '"float"'
---@return boolean @success?
---@return string @error message
function AudioRender.push(freq, channel, dtype)
	local hasffi
	---@type ffilib
	local ffi
	hasffi, ffi = pcall(require, "ffi")

	if not hasffi then
		return false, "FFI not found"
	end

	AudioRender.ffi = ffi
	local NULL = ffi.cast("void*", 0)

	-- Convert types
	local chantype = assert(CHANLOOKUP[channel], "invalid channel")
	local datatype = assert(DTYPELOOKUP[dtype], "invalid data type")

	if ffi.os == "Windows" then
		AudioRender.OpenAL32 = ffi.load("OpenAL32")
	elseif ffi.os == "Linux" then
		-- FIXME: Is this work?
		AudioRender.OpenAL32 = ffi.C
	else
		return false, "unsupported OS"
	end

	if not VALID_ARCH[ffi.arch] then
		return false, "unsupported architecture"
	end

	local oal = AudioRender.OpenAL32

	if not iscdef then
		local s, msg = pcall(CodeJumper.init)

		if not s then
			return false, msg
		end

		ffi.cdef[[
			void *alcOpenDevice(const char*);
			bool alcIsExtensionPresent(void*, const char*);
			void *alcCreateContext(void*, int*);
			void* alcGetProcAddress(void*, const char*);
		]]
		iscdef = true
	end

	-- Check loopback extension
	if not oal.alcIsExtensionPresent(nil, "ALC_SOFT_loopback") then
		return false, "missing ALC_SOFT_loopback extension"
	end

	-- Get loopback function addresses
	---@type fun(device: string): ffi.cdata*
	AudioRender.alcLoopbackOpenDeviceSOFT = ffi.cast("void*(*)(const char*)", oal.alcGetProcAddress(nil, "alcLoopbackOpenDeviceSOFT"))
	if AudioRender.alcLoopbackOpenDeviceSOFT == NULL then
		return false, "cannot retrieve alcLoopbackOpenDeviceSOFT function"
	end

	---@type fun(device: ffi.cdata*, buffer: integer[], size: integer)
	AudioRender.alcRenderSamplesSOFT = ffi.cast("void(*)(void*, void*, size_t)", oal.alcGetProcAddress(nil, "alcRenderSamplesSOFT"))
	if AudioRender.alcRenderSamplesSOFT == NULL then
		return false, "cannot retrieve alcRenderSamplesSOFT function"
	end

	-- Create hooked function
	local function alcOpenDevice(name)
		local device = AudioRender.alcLoopbackOpenDeviceSOFT(name)

		if device ~= NULL then
			AudioRender.lastDevice = device
		end

		return device
	end

	local function alcCreateContext(device, attrs)
		local needFreq, needFormatChan, needDataType = 2, 2, 2
		local nattrs2 = 0

		while true do
			local attrname = attrs[nattrs2]
			if attrname == 0 and attrs[nattrs2 + 1] == 0 then
				break
			end

			if attrname == 0x1007 then
				needFreq = 0
			elseif attrname == 0x1990 then
				needFormatChan = 0
			elseif attrname == 0x1991 then
				needDataType = 0
			end

			nattrs2 = nattrs2 + 2
		end

		local passedAttr = attrs
		if (needFreq + needFormatChan + needDataType) > 0 then
			local newAttrSize = nattrs2 + needFreq + needFormatChan + needDataType + 2
			local newAttr = ffi.new("int[?]", newAttrSize)

			for i = 0, newAttrSize - 3, 2 do
				newAttr[i], newAttr[i + 1] = attrs[i], attrs[i + 1]
			end

			if needFreq then
				newAttr[nattrs2], newAttr[nattrs2 + 1] = 0x1007, freq
				nattrs2 = nattrs2 + 2
			end

			if needFormatChan then
				newAttr[nattrs2], newAttr[nattrs2 + 1] = 0x1990, chantype
				nattrs2 = nattrs2 + 2
			end

			if needDataType then
				newAttr[nattrs2], newAttr[nattrs2 + 1] = 0x1991, datatype
				nattrs2 = nattrs2 + 2
			end

			newAttr[nattrs2], newAttr[nattrs2 + 1] = 0, 0
			passedAttr = newAttr
		end

		CodeJumper.unpatch(AudioRender.alcCreateContextPatch)
		local context = oal.alcCreateContext(device, passedAttr)
		AudioRender.alcCreateContextPatch = CodeJumper.patch(oal.alcCreateContext, AudioRender.alcCreateContextPtr)

		return context
	end

	-- Create memory allocations
	jit.off(alcOpenDevice)
	jit.off(alcCreateContext)
	AudioRender.alcOpenDevicePtr = ffi.cast("void*(*)(const char*)", alcOpenDevice)
	AudioRender.alcCreateContextPtr = ffi.cast("void*(*)(void*, int*)", alcCreateContext)

	-- Patch
	AudioRender.alcOpenDevicePatch = CodeJumper.patch(oal.alcOpenDevice, AudioRender.alcOpenDevicePtr)
	if not AudioRender.alcOpenDevicePatch then
		return false, "patching alcOpenDevice failed"
	end

	AudioRender.alcCreateContextPatch = CodeJumper.patch(oal.alcCreateContext, AudioRender.alcCreateContextPtr)
	if not AudioRender.alcCreateContextPatch then
		CodeJumper.unpatch(AudioRender.alcOpenDevicePatch)
		return false, "patching alcCreateContext failed"
	end

	AudioRender.success = true
	AudioRender.dataType = dtype
	AudioRender.channelType = channel
	return true
end

-- Restore patched code
function AudioRender.pop()
	if not AudioRender.success then return end

	AudioRender.success = false
	CodeJumper.unpatch(AudioRender.alcCreateContextPatch)
	CodeJumper.unpatch(AudioRender.alcOpenDevicePatch)
	AudioRender.alcOpenDevicePtr:free()
	AudioRender.alcCreateContextPtr:free()
end

-- Update
---@param smp integer
function AudioRender.update(smp)
	assert(AudioRender.lastDevice, "no devices")
	local dtype = DTYPEFFILOOKUP[AudioRender.dataType]
	local fullSampleSize = smp * CHANLOOKUPSIZE[AudioRender.channelType]

	if smp > updateBuffer[1] then
		updateBuffer[2] = AudioRender.ffi.new(dtype, fullSampleSize)
		updateBuffer[1] = smp
	end

	AudioRender.alcRenderSamplesSOFT(AudioRender.lastDevice, updateBuffer[2], smp)

	return AudioRender.ffi.string(updateBuffer[2], AudioRender.ffi.sizeof(dtype, fullSampleSize))
end

return AudioRender
