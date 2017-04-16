local love = require("love")

function love.touchpressed(id, x, y, dx, dy, pressure)
	return love.mousepressed(x, y, 1, id)
end

function love.touchreleased(id, x, y, dx, dy, pressure)
	return love.mousereleased(x, y, 1, id)
end

function love.touchmoved(id, x, y, dx, dy)
	return love.mousemoved(x, y, dx, dy, id)
end
