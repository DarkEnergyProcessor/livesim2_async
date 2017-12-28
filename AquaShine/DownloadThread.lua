-- Async, callback-based download (thread part)
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local cin = ...
local socket = require("socket")
local http = require("socket.http")
http.TIMEOUT = 120

-- AquaShine download event
local le = require("love.event")

local function push_event(name, data)
	le.push("aqs_download", cin, name, data)
end

local function check_if_quit()
	assert(cin:pop() ~= "QUIT", "Quit requested")
end

-- We create our custom sink function which does send
-- the response data to LOVE channel
local function custom_sink(chunk, err)
	check_if_quit()
	if chunk then
		push_event("RECV", chunk)
	end
	
	return 1
end

-- HTTP request function
local lasturl
local lasthttp
local request_http = socket.protect(function(url, headers)
	-- Build request table
	local h
	local dest, uri = assert(url:match("http://([^/]+)(/?.*)"))
	local host, port = dest:match("([^:]+):?(%d*)")
	port = #port > 0 and port or "80"
	local fulldest = host..":"..port
	if lasturl == fulldest and lasthttp and lasthttp.c:getsockname() then
		-- Keep-alive
		h = lasthttp
	else
		-- New connection
		if lasthttp then
			lasthttp:close()
		end
		
		h = http.open(host, assert(tonumber(port)))
	end
	lasthttp = nil
	lasturl = fulldest
	
	-- Adjust
	local basic_header = {
		["host"] = dest,
		["connection"] = "keep-alive",
		["keep-alive"] = "timeout=60",
		["user-agent"] = "AquaShine.Download "..socket._VERSION
	}
	
	-- Override headers
	for n, v in pairs(headers) do
		basic_header[n:lower()] = tostring(v)
	end
	h:sendrequestline("GET", #uri > 0 and uri or "/")
	h:sendheaders(basic_header)
	
	local code, status = h:receivestatusline()
	-- if it is an HTTP/0.9 server, simply get the body and we are done
	if not code then
		push_event("RESP", 200)
		push_event("SIZE", -1)
		h:receive09body(status, custom_sink)
		push_event("DONE", 0)
		h:close()
		return
	end
	
	local headers
	-- ignore any 100-continue messages
	while code == 100 do 
		headers = h:receiveheaders()
		code, status = h:receivestatusline()
	end
	headers = h:receiveheaders()
	
	push_event("RESP", code)
	push_event("SIZE", headers['content-length'] and tonumber(headers['content-length']) or -1)
	push_event("HEDR", headers)
	
	h:receivebody(headers, custom_sink)
	push_event("DONE", 0)
	
	-- If connection is still ok, keep it intact
	if h.c:getsockname() then
		lasthttp = h
	end
end)

local command = cin:demand()
while command ~= "QUIT" do
	print("command", command)
	local headers = cin:pop()
	local a, b, c = pcall(request_http, command, headers)
	
	if c then
		push_event("ERR ", c)
	end
	
	command = cin:demand()
end
