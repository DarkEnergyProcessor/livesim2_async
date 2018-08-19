-- Consistent graphics rendering
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local love_11 = love._version >= "11.0"
local rendering = {}

-- Default implementation for LOVE 11.0
function rendering.setColor(r, g, b, a)
	return love.graphics.setColor(r / 255, g / 255, b / 255, a / 255)
end
function rendering.draw(drawable, ...)
	return love.graphics.draw(drawable, ...)
end
function rendering.flush()
	return love.graphics.flushBatch()
end
function rendering.getColor()
	return love.graphics.getColor()
end

if not(love_11) then
	-- LOVE 0.10.2 and below: Use emulated autobatch
	local dummytex = love.graphics.newCanvas(1, 1)
	rendering.spriteBatch = love.graphics.newSpriteBatch(dummytex, 16, "stream")
	rendering.spriteBatchBufsize = 16
	rendering.currentTexture = dummytex

	local function flushSpriteBatch()
		if rendering.spriteBatch:getCount() == 0 then return end
		local r, g, b, a = love.graphics.getColor()
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(rendering.spriteBatch)
		rendering.spriteBatch:clear()
		love.graphics.setColor(r, g, b, a)
	end

	function rendering.setColor(r, g, b, a)
		love.graphics.setColor(r, g, b, a)
		return rendering.spriteBatch:setColor(r, g, b, a)
	end

	function rendering.draw(drawable, ...)
		if drawable:typeOf("Texture") then
			if rendering.currentTexture ~= drawable then
				flushSpriteBatch()
				rendering.currentTexture = drawable
				rendering.spriteBatch:setTexture(drawable)
			end

			-- If the batch is too big, increase the size
			if rendering.spriteBatch:getCount() == rendering.spriteBatchBufsize then
				rendering.spriteBatchBufsize = rendering.spriteBatchBufsize * 2
				rendering.spriteBatch:setBufferSize(rendering.spriteBatchBufsize)
			end

			-- Add
			rendering.spriteBatch:add(drawable, ...)
		else
			-- Huh? Why bother.
			flushSpriteBatch()
			return love.graphics.draw(drawable, ...)
		end
	end

	function rendering.flush()
		-- Only one of them should trigger.
		return flushSpriteBatch()
	end
end

return rendering
