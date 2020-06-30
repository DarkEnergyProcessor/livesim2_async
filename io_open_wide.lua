-- io.open patch to allow UTF-8 filenames in Windows
-- Copyright (c) 2020 Miku AuahDark
-- You can use portion of this code or as a whole without my permission.

local ffi = require("ffi")

if ffi.os ~= "Windows" then
	-- Not Windows
	return
end

-- Safety measures from redefining
do
	local function index(t, k)
		return t[k]
	end

	if pcall(index, ffi.C, "GetACP") then
		-- Has been patched!
		return
	end
end

ffi.cdef[[
uint32_t __stdcall GetACP();
]]

if ffi.C.GetACP() == 65001 then
	-- "Use Unicode UTF-8 for worldwide language support" is ticked.
	-- Don't bother patching it.
	return
end

ffi.cdef[[
int32_t __stdcall MultiByteToWideChar(
	uint32_t CodePage,
	uint32_t dwFlags,
	const char *lpMultiByteStr,
	int32_t cbMultiByte,
	wchar_t *lpWideCharStr,
	int32_t cchWideChar
);
void *_wfreopen(wchar_t *path, wchar_t *mode, void *file);
]]

local MB_ERR_INVALID_CHARS = 0x8

local function toWideChar(ch)
	local size = ffi.C.MultiByteToWideChar(65001, MB_ERR_INVALID_CHARS, ch, #ch, nil, 0)
	if size == 0 then
		error("invalid character sequence")
	end

	local buf = ffi.new("wchar_t[?]", size + 1)
	if ffi.C.MultiByteToWideChar(65001, MB_ERR_INVALID_CHARS, ch, #ch, buf, size) == 0 then
		error("char conversion error")
	end

	return buf
end

local open = io.open

function io.open(path, mode)
	local pathw = toWideChar(path)
	local modew = toWideChar(mode)

	local file = assert(open("nul", "rb"))
	if ffi.C._wfreopen(pathw, modew, file) == nil then
		local msg, errno = select(2, file:close())
		return nil, path..": "..msg, errno
	end

	return file
end
