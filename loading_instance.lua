-- Loading screen singleton
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local LoadingInstance = {}

function LoadingInstance.set(loading)
	assert(LoadingInstance.loading == nil, "Loading screen already exist")
	LoadingInstance.loading = loading
end

function LoadingInstance.getInstance()
	return LoadingInstance.loading
end

function LoadingInstance.exit()
	if LoadingInstance.loading then
		LoadingInstance.loading:exit()
	end
end

return LoadingInstance
