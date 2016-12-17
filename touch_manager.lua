local love = love
local TouchQueue = {}

function love.touchpressed(id, x, y, dx, dy, pressure)
	print("Press", tostring(id), x, y, dx, dy, pressure)
	
	--[[
	local i = 1
	while i < 64 do
		if TouchQueue[i] == nil then
			TouchQueue[i] = id
			return love.mousepressed(x, y, 1, i)
		end
		
		i = i + 1
	end
	]]
	return love.mousepressed(x, y, 1, id)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	print("Release", tostring(id), x, y, dx, dy, pressure)
	
	--[[
	local i = 1
	while i < 64 do
		if TouchQueue[i] == id then
			TouchQueue[i] = nil
			return love.mousereleased(x, y, 1, i)
		end
	end
	]]
	return love.mousereleased(x, y, 1, id)
end
