-- Object cache system
-- Part of Live Simulator: 2

local cache = {
	list = setmetatable({}, {__mode = "kv"})
}

function cache.get(name)
	return cache.list[name]
end

function cache.set(name, value)
	cache.list[name] = value
end

return cache
