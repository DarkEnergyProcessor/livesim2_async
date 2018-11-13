-- Download Manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local input = ...
--local love = require("love")
local socket = require("socket")
local http = require("socket.http")
local TAG = "download"

require("love.event") -- needed

http.TIMEOUT = 10

local function pushEvent(name, ...)
	return love.event.push(TAG, input, name, ...)
end

-- This custom sink sends the data to LOVE main thread
local function customSink(chunk)
	if input:peek() then
		return nil, "quit requested"
	elseif chunk then
		pushEvent("recv", chunk)
	end

	return 1
end

local function sendHTTP(h, v)
	if input:peek() then
		return nil, "quit requested"
	else
		return h.c:send(v)
	end
end

local function getHTTPHandle(url)
	local h
	local s, dest, uri = socket.try(url:match("http(s?)://([^/]+)(/?.*)"))
	local host, port = dest:match("([^:]+):?(%d*)")

	port = #port > 0 and port or "80"
	port = socket.try(tonumber(port), "invalid port")
	socket.try(#s == 0, "HTTPS is not supported")

	-- Open connection
	h = http.open(host, port) -- sometime it hangs in here
	return h, #uri == 0 and "/" or uri, dest
end

local requestHTTP = socket.protect(function(url, sentHeaders)
	-- Build request table
	local h, uri, dest = getHTTPHandle(url)

	-- Adjust
	local basicHeader = {
		["Host"] = dest,
		-- Tell server not to keep connections
		["Connection"] = "close",
		-- User-Agent backward compatibility
		["User-Agent"] = "AquaShine.Download "..socket._VERSION
	}

	-- Override headers
	for n, v in pairs(sentHeaders) do
		if v == math.huge then
			basicHeader[n:lower()] = nil
		else
			basicHeader[n:lower()] = tostring(v)
		end
	end

	do
		-- Generate HTTP header data
		local headerstr = {string.format("GET %s HTTP/1.1\r\n", uri)}
		for n, v in pairs(basicHeader) do
			headerstr[#headerstr + 1] = string.format("%s: %s\r\n", n, v)
		end
		headerstr[#headerstr + 1] = "\r\n"
		-- Send
		sendHTTP(h, table.concat(headerstr))
	end

	local code, status = h:receivestatusline()
	-- if it is an HTTP/0.9 server, simply get the body and we are done
	if not(code) then
		pushEvent("response", 200)
		pushEvent("size", -1)
		h:receive09body(status, customSink)
		pushEvent("done", 0)
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

	local size = tonumber(headers['content-length'] or headers['Content-Length']) or -1
	pushEvent("response", code)
	pushEvent("size", size)
	local tempchan = love.thread.newChannel()
	for k, v in pairs(tempchan) do
		tempchan:push(k)
		tempchan:push(v)
	end
	pushEvent("header", tempchan)

	h:receivebody(headers, customSink)
	h:close()
	pushEvent("done", 0)
	return 1, code, headers, status
end)

local destURL = input:pop()

local extraHeadersCount = input:pop()
local extraHeaders = {}
for _ = 1, extraHeadersCount do
	local n = input:pop()
	local v = input:pop()
	extraHeaders[n] = v
end

local a, b = requestHTTP(destURL, extraHeaders)
if not(a) then
	pushEvent("error", b)
end
