-- Post-exit handling code (incl. errorhandler)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local log = require("logging")
local PostExit = {list = {}}

function PostExit.add(func)
	PostExit.list[#PostExit.list + 1] = func
	if log.getLevel() >= 4 then
		log.debug("postExit", debug.traceback(string.format("added handler %d", #PostExit.list)))
	end
end

function PostExit.exit()
	for i = 1, #PostExit.list do
		local s, msg = xpcall(PostExit.list[i], debug.traceback)
		if not(s) then
			log.errorf("postExit", "failed to call exit function %d: %s", i, msg)
		end
	end
end

return PostExit
