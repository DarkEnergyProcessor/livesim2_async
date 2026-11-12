-- Fallback HTTPS requester using the system `curl` command
-- Used by the download manager when lua-https isn't built into LOVE
-- (e.g. stock LOVE 11.x on macOS/Linux). Mimics https.request().

local curlHttps = {}

local function shellQuote(s)
	return "'"..tostring(s):gsub("'", "'\\''").."'"
end

local function readFile(path, mode)
	local f = io.open(path, mode or "rb")
	if not f then return nil end
	local data = f:read("*a")
	f:close()
	return data
end

-- os.execute returns 0 in Lua 5.1/LuaJIT and true in Lua 5.2+
local function run(cmd)
	local r = os.execute(cmd)
	return r == 0 or r == true
end

local available
function curlHttps.available()
	if available == nil then
		local ok, res = pcall(run, "command -v curl >/dev/null 2>&1")
		available = ok and res or false
	end
	return available
end

---@param url string
---@param opts {headers: table<string, string>}
---@return integer|nil code, string body, table<string, string> headers
function curlHttps.request(url, opts)
	opts = opts or {}
	local headFile, bodyFile, errFile = os.tmpname(), os.tmpname(), os.tmpname()
	local args = {"curl", "-sS", "--max-time", "120", "-D", shellQuote(headFile), "-o", shellQuote(bodyFile)}

	for k, v in pairs(opts.headers or {}) do
		args[#args + 1] = "-H"
		args[#args + 1] = shellQuote(k..": "..tostring(v))
	end

	args[#args + 1] = shellQuote(url)
	args[#args + 1] = "2>"..shellQuote(errFile)

	run(table.concat(args, " "))

	local head = readFile(headFile, "r") or ""
	local body = readFile(bodyFile, "rb") or ""
	local errOut = readFile(errFile, "r") or ""
	os.remove(headFile)
	os.remove(bodyFile)
	os.remove(errFile)

	-- Parse the last response block (curl writes one per response)
	local code, headers = nil, {}
	for line in head:gmatch("[^\r\n]*") do
		local status = line:match("^HTTP/[%d%.]+%s+(%d+)")
		if status then
			code, headers = tonumber(status), {}
		elseif code and #line > 0 then
			local k, v = line:match("^(.-):%s*(.*)$")
			if k then headers[k] = v end
		end
	end

	if not code then
		return nil, (#errOut > 0 and errOut or "curl request failed"), {}
	end

	return code, body, headers
end

return curlHttps
