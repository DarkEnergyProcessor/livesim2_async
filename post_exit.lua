-- Post-exit handling code (incl. errorhandler)
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local postExit = {list = {}}
function postExit.add(func)
	postExit.list[#postExit.list + 1] = func
end

function postExit.exit()
	for i = 1, #postExit.list do
		postExit.list[i]()
	end
end

return postExit
