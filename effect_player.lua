local table = table
local pairs = pairs
local graphics = love.graphics
local ep = {}
local ep_list = {}

ep.list = ep_list

-- Should be already coroutine-wrapped.
function ep.Spawn(func)
	table.insert(ep_list, func)
end

function ep.Update(deltaT)
	-- Always iterate in reverse order
	for i = #ep_list, 1, -1 do
		if ep_list[i](deltaT) then
			table.remove(ep_list, i)
		end
	end
end

return ep
