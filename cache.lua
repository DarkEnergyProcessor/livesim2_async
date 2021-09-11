-- Object cache system
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Cache = {
	list = setmetatable({}, {__mode = "kv"})
}

--- Get value from cache
-- @tparam string name Cache name
-- @return Cached value, or nil
function Cache.get(name)
	return Cache.list[name]
end

--- Set cached value by name
-- @tparam string name Cache name
-- @param value Value to be cached
function Cache.set(name, value)
	Cache.list[name] = value
end

return Cache
