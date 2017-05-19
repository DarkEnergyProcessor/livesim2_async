-- Live Simulator: 2 beatmap loader
-- Part of Live Simulator: 2

local ls2 = require("ls2")

local LS2Beatmap = {
	Name = "Live Simulator: 2 Binary Beatmap",
	Extension = "ls2"
}

-----------------------------
-- Beatmap Loader Routines --
-----------------------------

function LS2Beatmap.Load(file, depls_folder)
	local f = love.filesystem.newFile(file[1]..".ls2")
	assert(f:open("r"))
	
	return ls2.parsestream(f)
end

return LS2Beatmap
