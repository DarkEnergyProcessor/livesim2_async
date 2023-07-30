-- Download Manager
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local TAG, input = ...
local love = require("love")
local socket = require("socket")
local log = require("logging")
local hashttps, https = pcall(require, "https")

require("love.event")
require("love.timer")

local function pushEvent(name, ...)
	return love.event.push(TAG, input, name, ...)
end

local function socketSend(s, v)
	if input:peek() then
		return nil, "cancelled"
	else
		return s:send(v)
	end
end

local function socketReceive(s, ...)
	if input:peek() then
		return nil, "cancelled"
	end

	local time = love.timer.getTime()
	local a, b, c = s:receive(...)
	while a == nil and b == "timeout" do
		if input:peek() then
			return nil, "cancelled"
		end

		if #c > 0 then
			return c, nil, nil
		end

		if love.timer.getTime() - time >= 60 then
			return nil, "timeout", c
		end

		love.timer.sleep(0.005)
		a, b, c = s:receive(...)
	end

	return a, b, c
end

local lastSocketHandle, lastDest

local function invalidateCache()
	if lastSocketHandle then lastSocketHandle:close() end
	lastDest = nil
end

local function getHTTPHandle(url, new)
	local h
	local s, dest, uri = url:match("http(s?)://([^/]+)(/?.*)")
	assert(dest, "invalid url")
	local host, port = dest:match("([^:]+):?(%d*)")

	port = #port > 0 and port or "80"
	port = assert(tonumber(port), "invalid port")
	assert(#s == 0, "HTTPS is not supported")

	-- Open connection
	if lastDest == dest and not(new) then
		log.debugf(TAG, "get HTTP handle %s: use existing", dest)
		h = lastSocketHandle
	else
		log.debugf(TAG, "get HTTP handle %s: new connection", dest)
		invalidateCache()
		h = assert(socket.connect(host, port))
		h:settimeout(0)
		lastSocketHandle, lastDest = h, dest
	end

	return h, #uri == 0 and "/" or uri, dest
end

local function receiveWithLength(h, length)
	while length > 0 do
		local chunk, err, partial = socketReceive(h, math.min(2048, length))
		if err then
			if err == "closed" then
				pushEvent("receive", partial)
			end

			return nil, err
		end
		length = length - string.len(chunk)
		pushEvent("receive", chunk)
	end

	return true
end

---@param url string
---@param location string
local function getNewRedirectLocation(url, location)
	if location:find("https://", 1, true) == 1 or location:find("http://", 1, true) == 1 then
		-- Absolute
		return location
	elseif location:find("/", 1, true) == 1 then
		-- Still absolute, but use the existing protocol and domain
		local protocol = assert(url:find("//", 1, true), "missing protocol")
		local firstSlash = url:find("/", protocol + 2, true)
		if firstSlash then
			return url:sub(1, firstSlash)..location
		else
			return url..location
		end
	else
		if url:sub(-1) ~= "/" then
			url = url.."/"
		end

		local reverse = url:reverse()
		local slash = assert(reverse:find("/", 1, true))
		local stripped = reverse:sub(slash):reverse()
		return stripped..location
	end
end

local delegateHTTPCall

local function requestHTTPReal(h, uri, dest, url, sentHeaders)
	-- Adjust
	local basicHeader = {
		["Host"] = dest,
		-- Excuse me wtf?
		["User-Agent"] = "AquaShine.Download "..socket._VERSION
	}
	log.debug(TAG, "Main headers:")
	log.debugf(TAG, "Host: %s", basicHeader.Host)
	log.debugf(TAG, "User-Agent: %s", basicHeader["User-Agent"])

	-- Override headers
	for n, v in pairs(sentHeaders) do
		if n ~= "expect" and n ~= "Expect" then
			if v == math.huge then
				basicHeader[n:lower()] = nil
			else
				basicHeader[n:lower()] = tostring(v)
			end
		end
	end

	-- Generate HTTP header data
	local baseHeader = {string.format("GET %s HTTP/1.1\r\n", uri)}
	for n, v in pairs(basicHeader) do
		baseHeader[#baseHeader + 1] = string.format("%s: %s\r\n", n, v)
	end
	baseHeader[#baseHeader + 1] = "\r\n"
	local headerstr = table.concat(baseHeader)
	-- Send
	if input:getCount() > 0 then
		log.warnf(TAG, "input not empty (%s)", input:peek())
	end
	log.debugf(TAG, "trying to send this message:\n%s", headerstr)
	local res, msg = socketSend(h, headerstr)
	log.debugf(TAG, "send status is %s (%s)", tostring(res), tostring(msg))

	if res == nil and msg == "closed" then
		-- Well, the keep-alive connection is closed
		h = getHTTPHandle(url, true)
		assert(socketSend(h, headerstr))
	elseif res == nil then
		error(msg)
	end

	local statusLine, msg = socketReceive(h, "*l")
	if statusLine == nil then
		if msg == "closed" then
			-- Well, the keep-alive connection is closed
			h = getHTTPHandle(url, true)
			assert(socketSend(h, headerstr))
			statusLine = assert(socketReceive(h, "*l"))
		else
			error(msg)
		end
	end

	local statusCode = tonumber(statusLine:match("HTTP/%d+%.%d+ (%d+)"))

	-- receive headers
	local receivedHeaders = {}
	while true do
		local data = assert(socketReceive(h, "*l"))
		if #data == 0 then break end
		local key, value = data:match("^(.-):%s*(.*)")
		receivedHeaders[key:lower()] = tonumber(value) or value
	end

	if math.floor(statusCode / 100) == 1 then
		error("100 response is not supported")
	elseif statusCode == 301 or statusCode == 302 then
		-- Redirection
		local target = assert(receivedHeaders["location"])
		local newURL = getNewRedirectLocation(url, target)
		return delegateHTTPCall(newURL, sentHeaders)
	end

	-- receive body
	local transferEncoding = receivedHeaders["transfer-encoding"]
	local chunked = transferEncoding == "chunked"

	if transferEncoding and not chunked and transferEncoding ~= "identity" then
		error("Transfer-Encoding "..transferEncoding.." is not currently supported")
	end

	local size = receivedHeaders["content-length"]

	-- send data
	local tempchan = love.thread.newChannel()
	for k, v in pairs(receivedHeaders) do
		tempchan:push(k)
		tempchan:push(v)
	end
	pushEvent("response", statusCode, tempchan, size)

	-- some status code specialization
	if statusCode == 304 then
		size = 0
	end

	if size == nil then
		if chunked then
			-- receive chunk
			while true do
				local data, err = socketReceive(h, "*l")

				if not(err) then
					local length = tonumber(data, 16)

					if length and length == 0 then
						break
					end

					local result, errmsg = receiveWithLength(h, length)

					if not(result) then
						invalidateCache()
						return nil, errmsg
					end
				elseif err == "closed" then
					invalidateCache()
					break
				end
			end
		else
			-- receive until closed
			local chunk, err, partial = socketReceive(h, 2048)
			if not(err) then
				pushEvent("receive", chunk)
			elseif err == "closed" then
				invalidateCache()
				pushEvent("receive", partial)
			else
				return nil, err
			end
		end
	else
		local result, errmsg = receiveWithLength(h, size)

		if not(result) then
			invalidateCache()
			return nil, errmsg
		end
	end

	if receivedHeaders["connection"] and receivedHeaders["connection"]:find("close", 1, true) == 1 then
		invalidateCache()
	end

	pushEvent("done")
	return true
end

local function requestHTTP(url, sentHeaders)
	-- get handle
	local h, uri, dest = getHTTPHandle(url)
	local s, msg = pcall(requestHTTPReal, h, uri, dest, url, sentHeaders)
	if not(s) then
		invalidateCache()
		if input:peek() == "cancel" then
			input:pop()
		end
		pushEvent("error", msg)
	end

	return s
end

---@param url string
---@param sentHeaders table<string, string>
local function requestHTTPS(url, sentHeaders)
	if not hashttps then
		error("Lua HTTPS is not available")
	end

	local newHeaders = {}
	for k, v in pairs(sentHeaders) do
		newHeaders[k] = v
	end
	newHeaders["User-Agent"] = "AquaShine.Download "..socket._VERSION

	local code, body, headers = https.request(url, {headers = newHeaders})
	if code == nil then
		error(body)
	elseif code == 0 then
		error("request failed unknown error")
	elseif math.floor(code / 100) == 1 then
		error("100 response is not supported")
	else
		local receivedHeaders = {}
		for k, v in pairs(headers) do
			receivedHeaders[k:lower()] = v
		end

		if code == 301 or code == 302 then
			-- Redirection
			local target = assert(receivedHeaders["location"])
			local newURL = getNewRedirectLocation(url, target)
			return delegateHTTPCall(newURL, sentHeaders)
		end

		local tempchan = love.thread.newChannel()
		for k, v in pairs(receivedHeaders) do
			tempchan:push(k)
			tempchan:push(v)
		end

		pushEvent("response", code, tempchan, receivedHeaders["content-length"])
		pushEvent("receive", body)
		pushEvent("done")
		return true
	end
end

---@param url string
---@param sentHeaders table<string, string>
function delegateHTTPCall(url, sentHeaders)
	if url:sub(1, 8) == "https://" then
		return requestHTTPS(url, sentHeaders)
	else
		return requestHTTP(url, sentHeaders)
	end
end

while true do
	---@type string
	local destURL = input:demand()
	if destURL == "quit://" then
		log.debugf(TAG, "quit requested")
		return
	end
	log.debugf(TAG, "received download command %s", destURL)

	if destURL == nil then
		pushEvent("error", "empty URL")
	else
		---@type table<string, string>
		local extraHeaders = {}
		local hasExtraHeaders = input:demand()
		while hasExtraHeaders do
			local n = input:demand()
			local v = input:demand()
			log.debugf(TAG, "collect extra headers: %s = %s", n, v)
			extraHeaders[n] = v
			hasExtraHeaders = input:demand()
		end

		log.debugf(TAG, "initiating download call")
		local a, b = pcall(delegateHTTPCall, destURL, extraHeaders)
		if not(a) then
			pushEvent("error", b)
		end
	end

	collectgarbage()
end
