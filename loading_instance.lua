-- Loading screen singleton
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local loadingInstance = {}

function loadingInstance.set(loading)
	assert(loadingInstance.loading == nil, "Loading screen already exist")
	loadingInstance.loading = loading
end

function loadingInstance.getInstance()
	return loadingInstance.loading
end

function loadingInstance.exit()
	if loadingInstance.loading then
		loadingInstance.loading:exit()
	end
end

return loadingInstance
