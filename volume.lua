-- A very simple volume calculator
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local Volume = {
	list = {master = 0.8}
}

-- volume default initialized to 0.8
function Volume.define(name, value)
	assert(Volume.list[name] == nil, "name already defined")
	Volume.list[name] = assert(tonumber(value), "invalid default volume")
end

-- value default to 1 if not specified
function Volume.get(name, value)
	assert(Volume.list[name], "name doesn't exist")
	value = value or 1
	if name == "master" then
		return Volume.list.master * value
	else
		return Volume.list.master * Volume.list[name] * value
	end
end

-- usually settings set the volume
function Volume.set(name, value)
	Volume.list[name] = assert(tonumber(value), "invalid volume")
end

return Volume
