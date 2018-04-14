-- Just a simple effect player queue
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local ep = {}
local ep_list = {}

ep.list = ep_list

function ep.Spawn(udata, func, func2)
	local temp = {}
	temp.Userdata = udata
	temp.Update = func or udata.Update
	temp.Draw = func2 or udata.Draw

	ep_list[#ep_list + 1] = temp
end

function ep.Update(deltaT)
	-- Always iterate in reverse order
	for i = #ep_list, 1, -1 do
		if ep_list[i].Update(ep_list[i].Userdata, deltaT) then
			table.remove(ep_list, i)
		end
	end
end

function ep.Draw()
	for i = #ep_list, 1, -1 do
		ep_list[i].Draw(ep_list[i].Userdata)
	end
end

function ep.Clear()
	for i = #ep_list, 1, -1 do
		ep_list[i] = nil
	end
end

return ep
