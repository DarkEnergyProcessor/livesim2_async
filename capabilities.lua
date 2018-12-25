-- Capabilities string
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

-- luacheck: read_globals DEPLS_VERSION
-- luacheck: read_globals DEPLS_VERSION_NUMBER

local ls2x = require("libs.ls2x")

return function()
	local bld = {}

	-- Query capabilities
	if os.getenv("LLA_IS_SET") then
		-- From modified Openal-Soft
		bld[#bld + 1] = "LLA:"..os.getenv("LLA_BUFSIZE").."smp/"..os.getenv("LLA_FREQUENCY").."Hz"
	end

	if jit and jit.status() then
		bld[#bld + 1] = "JIT"
	end

	if package.preload.lvep then
		bld[#bld + 1] = "FFXNative"
	end

	if ls2x.libav and ls2x.libav.startEncodingSession then
		bld[#bld + 1] = "VideoRender"
	end

	return table.concat(bld, " ")
end
