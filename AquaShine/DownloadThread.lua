-- Async, callback-based download (thread part)
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local cin = ...
local http = require("socket.http")
local url = require("socket.url")

-- AquaShine download event
local le = require("love.event")

local function push_event(name, data)
	le.push("aqs_download", cin, name, data)
end

-- From Luasocket 2.0.2 with some modifications
-- where proxy and authentication is removed
local default = {
	host = "",
	port = PORT,
	path ="/",
	scheme = "http"
}

local function adjusturi(reqt)
	return url.build {
	   path = assert(reqt.path, "invalid path 'nil'"),
	   params = reqt.params,
	   query = reqt.query,
	   fragment = reqt.fragment
	}
end

local function adjustheaders(reqt)
	-- default headers
	local lower = {
		["host"] = reqt.host,
		["connection"] = "close, TE",
		["te"] = "trailers"
	}
	-- override with user headers
	for i,v in pairs(reqt.headers or lower) do
		lower[string.lower(i)] = v
	end
	return lower
end

-- default url parts
local default = {
	host = "",
	port = PORT,
	path ="/",
	scheme = "http"
}

local function check_if_quit()
	assert(cin:pop() ~= "QUIT", "Quit requested")
end

local function adjustrequest(reqt)
	-- parse url if provided
	local nreqt = reqt.url and url.parse(reqt.url, default) or {}
	-- explicit components override url
	for i,v in pairs(reqt) do nreqt[i] = v end
	if nreqt.port == "" then nreqt.port = 80 end
	assert(nreqt.host and nreqt.host ~= "", "invalid host")
	-- compute uri if user hasn't overriden
	nreqt.uri = reqt.uri or adjusturi(nreqt)
	-- adjust headers in request
	nreqt.headers = adjustheaders(nreqt)
	return nreqt
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
local request_http = socket.protect(function(url, headers)
	-- Build request table
	local req = {}
	req.url = url
	req.sink = custom_sink
	
	-- Adjust
	local nreqt = adjustrequest(req)
	local h = http.open(nreqt.host, nreqt.port, nreqt.create)
	h:sendrequestline(nreqt.method, nreqt.uri)
	
	-- Override headers
	for n, v in pairs(headers) do
		nreqt.headers[n:lower()] = tostring(v)
	end
	h:sendheaders(nreqt.headers)
	
	local code, status = h:receivestatusline()
	-- if it is an HTTP/0.9 server, simply get the body and we are done
	if not code then
		push_event("RESP", 200)
		push_event("SIZE", -1)
		h:receive09body(status, nreqt.sink, nreqt.step)
		push_event("DONE", 0)
		
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
	
	h:receivebody(headers, nreqt.sink, nreqt.step)
	h:close()
	
	push_event("DONE", 0)
end)

local command = cin:demand()
while command ~= "QUIT" do
	local headers = cin:pop()
	local a, b, c = pcall(request_http, command, headers)
	
	if c then
		push_event("ERR ", c)
	end
	
	command = cin:demand()
end
