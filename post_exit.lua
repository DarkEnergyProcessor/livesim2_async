-- Post-exit handling code (incl. errorhandler)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local log = require("logging")
local postExit = {list = {}}

function postExit.add(func)
	postExit.list[#postExit.list + 1] = func
	if log.getLevel() >= 4 then
		log.debug("postExit", debug.traceback(string.format("added handler %d", #postExit.list)))
	end
end

function postExit.exit()
	for i = 1, #postExit.list do
		local s, msg = xpcall(postExit.list[i], debug.traceback)
		if not(s) then
			log.errorf("postExit", "failed to call exit function %d: %s", i, msg)
		end
	end
end

return postExit
