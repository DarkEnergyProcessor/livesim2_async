-- A very simple volume calculator
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local volume = {
	list = {master = 0.8}
}

-- volume default initialized to 0.8
function volume.define(name, value)
	assert(volume.list[name] == nil, "name already defined")
	volume.list[name] = assert(tonumber(value), "invalid default volume")
end

-- value default to 1 if not specified
function volume.get(name, value)
	assert(volume.list[name], "name doesn't exist")
	if name == "master" then
		return volume.list.master * value
	else
		return volume.list.master * volume.list[name] * value
	end
end

-- usually settings set the volume
function volume.set(name, value)
	volume.list[name] = assert(tonumber(value), "invalid volume")
end

return volume
