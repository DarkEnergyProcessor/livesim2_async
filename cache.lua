-- Object cache system
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local cache = {
	list = setmetatable({}, {__mode = "kv"})
}

--- Get value from cache
-- @tparam string name Cache name
-- @return Cached value, or nil
function cache.get(name)
	return cache.list[name]
end

--- Set cached value by name
-- @tparam string name Cache name
-- @param value Value to be cached
function cache.set(name, value)
	cache.list[name] = value
end

return cache
