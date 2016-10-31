local List = {}

function List.new()
	local out = {first = 0, last = -1}
	local lenfunc = function()
		return out.last - out.first + 1
	end
	
	setmetatable(out, {
		__index = function(_, var)
			if var == "first" or var == "last" then
				return rawget(_, var)
			elseif var == "len" then
				return lenfunc()
			else
				return List[var]
			end
		end,
		__len = lenfunc
	})
	
	return out
end

function List.pushleft(list, value)
	local first = list.first - 1
	list.first = first
	list[first] = value
end

function List.pushright(list, value)
	local last = list.last + 1
	list.last = last
	list[last] = value
end

function List.popleft(list)
	local first = list.first
	if first > list.last then error("list is empty") end
	local value = list[first]
	list[first] = nil				-- to allow garbage collection
	list.first = first + 1
	return value
end

function List.popright(list)
	local last = list.last
	if list.first > last then error("list is empty") end
	local value = list[last]
	list[last] = nil				 -- to allow garbage collection
	list.last = last - 1
	return value
end

function List.isempty(list)
	return list.first > list.last
end

return List
