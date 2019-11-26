-- File Selection system
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local log = require("logging")

local fileDialog = {}
local hasShell = os.execute() == 1

if not(hasShell) then
	log.warn("fileDiag", "possible file dialog backend detection fail")
end

if love._os == "Windows" and package.preload.ffi then
	-- Use native OpenFileName for Windows with FFI
	local ffi = require("ffi")
	local Comdlg32 = ffi.load("Comdlg32")

	ffi.cdef [[
		int MultiByteToWideChar(unsigned int codepage, unsigned long flags, const char* str, int strlen, wchar_t* wstr, int wstrlen);
		int WideCharToMultiByte(unsigned int codepage, unsigned long flags, const wchar_t* wstr, int wstrlen, char* str, int strlen, char* defchr, int* udefchr);

		typedef struct {
			unsigned long	lStructSize;
			void*			hwndOwner;
			void*			hInstance;
			const wchar_t*	lpstrFilter;
			wchar_t*		lpstrCustomFilter;
			unsigned long	nMaxCustFilter;
			unsigned long	nFilterIndex;
			wchar_t*		lpstrFile;
			unsigned long	nMaxFile;
			wchar_t*		lpstrFileTitle;
			unsigned long 	nMaxFileTitle;
			const wchar_t*	lpstrInitialDir;
			const wchar_t*	lpstrTitle;
			unsigned long 	flags;
			unsigned short	nFileOffset;
			unsigned short	nFileExtension;
			const wchar_t*	lpstrDefExt;
			unsigned long	lCustData;
			void*			lpfnHook;
			const wchar_t*	lpTemplateName;
			void*			pvReserved;
			unsigned long	dwReserved;
			unsigned long	flagsEx;
		} OPENFILENAMEW;

		int GetOpenFileNameW(OPENFILENAMEW *lpofn);
	]]

	-- Returned length excludes null-terminated string
	local function UTF8ToUTF16(utf8)
		local ptr = ffi.cast("const char*", utf8)
		local len = ffi.C.MultiByteToWideChar(65001, 0, ptr, #utf8, nil, 0)
		local utf16 = ffi.new("wchar_t[?]", len)

		assert(ffi.C.MultiByteToWideChar(65001, 0, ptr, #utf8, utf16, len) > 0, "Conversion failed")

		return utf16, len
	end

	-- Returned is Lua string
	local function UTF16ToUTF8(utf16, len)
		len = len or -1
		local mblen = ffi.C.WideCharToMultiByte(65001, 0, utf16, len, nil, 0, nil, nil)
		local mb = ffi.new("char[?]", mblen)

		assert(ffi.C.WideCharToMultiByte(65001, 0, utf16, len, mb, mblen, nil, nil) > 0, "Conversion failed")

		return ffi.string(mb, mblen)
	end

	local allfiles
	function fileDialog.open(title, directory, filter, multiple)
		local ofnptr = ffi.new("OPENFILENAMEW[1]")
		local ofn = ofnptr[0]
		local null = ffi.cast("void*", 0)

		if not(allfiles) then
			allfiles = UTF8ToUTF16("All Files\0*.*\0\0")
		end

		ofn.lStructSize = ffi.sizeof("OPENFILENAMEW")
		ofn.hwndOwner = null

		ofn.lpstrFile = ffi.new("wchar_t[32768]")
		ofn.nMaxFile = 32767

		ofn.nFilterIndex = 1

		if filter then
			ofn.lpstrFilter = UTF8ToUTF16("Specific Files ("..filter..")\0"..filter:gsub(" ", ";").."\0\0")
		else
			ofn.lpstrFilter = allfiles
		end

		if title then
			ofn.lpstrTitle = UTF8ToUTF16(title.."\0")	-- Lua string len doesn't add null terminator
		end

		ofn.lpstrFileTitle = nil
		ofn.nMaxFileTitle = 0

		if directory then
			ofn.lpstrInitialDir = UTF8ToUTF16(directory:gsub("/", "\\").."\0")
		end

		ofn.flags = 0x02081804 + (multiple and 0x00000200 or 0)

		if Comdlg32.GetOpenFileNameW(ofnptr) > 0 then
			if multiple then
				local list = {}
				local dir = UTF16ToUTF8(ofn.lpstrFile):sub(1, -2):gsub("\\", "/")
				local ptr = ofn.lpstrFile + #dir + 1

				if dir:sub(-1) == "/" then
					dir = dir:sub(1, -2)
				end

				while ptr[0] ~= 0 do
					local name = UTF16ToUTF8(ptr)

					list[#list + 1] = dir.."/"..name:sub(1, -2)
					ptr = ptr + #name
				end

				if #list == 0 then
					list[1] = dir
				end

				return list
			else
				return UTF16ToUTF8(ofn.lpstrFile)
			end
		end

		if multiple then return {} end
		return nil
	end
elseif love._os == "Linux" and hasShell then
	if os.execute("command -v kdialog >/dev/null 2>&1") == 0 then
		function fileDialog.open(title, directory, filter, multiple)
			-- title and multiple is not supported unfortunately
			local cmdbuild = {}

			cmdbuild[#cmdbuild + 1] = "kdialog --getopenfilename"

			if directory then
				cmdbuild[#cmdbuild + 1] = string.format("%q", directory)
			end

			if filter then
				cmdbuild[#cmdbuild + 1] = string.format("'%s|Specific Files (%s)'", filter, filter)
			end

			local cmd = assert(io.popen(table.concat(cmdbuild, " ")))
			local list = cmd:read("*a")
			cmd:close()

			if #list > 0 then
				list = list:gsub("[\r\n|\r|\n]+", "")

				if multiple then
					return {list}
				else
					return list
				end
			else
				if multiple then
					return {}
				else
					return nil
				end
			end
		end
	elseif os.execute("command -v zenity >/dev/null 2>&1") == 0 then
		function fileDialog.open(title, directory, filter, multiple)
			local cmdbuild = {}

			cmdbuild[#cmdbuild + 1] = "zenity --file-selection"

			if title then
				cmdbuild[#cmdbuild + 1] = string.format("--title=%q", title)
			end

			if filter then
				cmdbuild[#cmdbuild + 1] = "--file-filter='"..filter.."'"
			end

			if multiple then
				cmdbuild[#cmdbuild + 1] = "--multiple --separator='|'"
			end

			if directory then
				table.insert(cmdbuild, 1, string.format("(cd %q &&", directory))
				cmdbuild[#cmdbuild + 1] = ")"
			end

			local cmd = assert(io.popen(table.concat(cmdbuild, " ")))
			local list = cmd:read("*a")
			cmd:close()

			if #list == 0 then
				if multiple then
					return {}
				else
					return nil
				end
			end

			if multiple then
				local filelist = {}

				for w in list:gmatch("[^|]+") do
					filelist[#filelist + 1] = w:gsub("[\r\n|\r|\n]+", "")
				end

				return filelist
			else
				return list
			end
		end
	end
end

-- TODO: use SAF in Android 5.0 and later

function fileDialog.isSupported()
	return not(not(fileDialog.open))
end

return fileDialog
