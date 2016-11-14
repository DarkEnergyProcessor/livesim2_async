local stringstream = {}

function stringstream.create(str)
	local out = newproxy(true)
	local meta = getmetatable(out)
	
	meta.buffer = str or ""
	meta.pos = 0
	meta.__index = stringstream
	
	return out
end

function stringstream.read(ss, num)
	local meta = getmetatable(ss)
	
	if num == "*a" then
		if meta.pos == #meta.buffer then
			return nil
		end
		
		local out = meta.buffer:sub(meta.pos + 1)
		
		meta.pos = #meta.buffer
		return out
	elseif num <= 0 then
		return ""
	end
	
	local meta = getmetatable(ss)
	local out = meta.buffer:sub(meta.pos + 1, meta.pos + num)
	
	if #out == 0 then return nil end
	
	meta.pos = meta.pos + num
	
	if meta.pos > #meta.buffer then
		pos = #meta.buffer
	end
	
	return out
end

function stringstream.write(ss, ...)
	local meta = getmetatable(ss)
	local gap1 = meta.buffer:sub(1, meta.pos)
	local gap2 = meta.buffer:sub(meta.pos + 1)
	local con = {}
	
	for n, v in pairs({...}) do
		table.insert(con, tostring(v))
	end
	
	con = table.concat(con)
	meta.pos = meta.pos + #con
	meta.buffer = gap1..con..gap2
	
	return true
end

function stringstream.seek(ss, whence, offset)
	local meta = getmetatable(ss)
	
	whence = whence or "cur"
	
	if whence == "set" then
		meta.pos = offset or 0
	elseif whence == "cur" then
		meta.pos = meta.pos + (offset or 0)
	elseif whence == "end" then
		meta.pos = #meta.buffer + (offset or 0)
	else
		error("bad argument #1 to 'seek' (invalid option '"..tostring(whence).."')", 2)
	end
	
	if meta.pos < 0 then
		meta.pos = 0
	elseif meta.pos > #meta.buffer then
		meta.pos = #meta.buffer
	end
	
	return meta.pos
end

function stringstream.string(ss)
	return getmetatable(ss).buffer
end

return stringstream
