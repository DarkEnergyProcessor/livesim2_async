-- Consistent graphics rendering
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local love_11 = love._version >= "11.0"
local rendering = {}

-- Default implementation for LOVE 11.0
function rendering.setColor(r, g, b, a)
	return love.graphics.setColor(r, g, b, a)
end
function rendering.draw(drawable, ...)
	return love.graphics.draw(drawable, ...)
end
function rendering.setFont(font)
	return love.graphics.setFont(font)
end
function rendering.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
	return love.graphics.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
end
function rendering.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
	return love.graphics.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
end
function rendering.flush() end -- dummy

if not(love_11) then
	-- LOVE 0.10.2 and below: Use emulated autobatch
	local dummytex = love.graphics.newCanvas(1, 1)
	local dummyfont = love.graphics.newFont(12)
	rendering.spriteBatch = love.graphics.newSpriteBatch(dummytex, 16, "stream")
	rendering.spriteBatchBufsize = 16
	rendering.currentTexture = dummytex
	rendering.text = love.graphics.newText(dummyfont)
	rendering.currentFont = dummyfont

	local function isTextEmpty()
		local w, h = rendering.text:getDimensions()
		return w == 0 or h == 0
	end

	local function flushText()
		if isTextEmpty() then return end
		local r, g, b, a = love.graphics.getColor()
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(rendering.text)
		rendering.text:clear()
		love.graphics.setColor(r, g, b, a)
	end

	local function flushSpriteBatch()
		if rendering.spriteBatch:getCount() == 0 then return end
		local r, g, b, a = love.graphics.getColor()
		love.graphics.setColor(255, 255, 255)
		love.graphics.draw(rendering.spriteBatch)
		rendering.spriteBatch:clear()
		love.graphics.setColor(r, g, b, a)
	end

	function rendering.setFont(font)
		if rendering.currentFont ~= font then
			flushText()
			rendering.currentFont = font
			rendering.text:setFont(font)
		end
	end

	function rendering.print(text, x, y, r, sx, sy, ox, oy, kx, ky)
		local m, g, b, a = love.graphics.getColor()
		flushSpriteBatch()
		rendering.text:add({{m, g, b, a}, text}, x, y, r, sx, sy, ox, oy, kx, ky)
	end

	function rendering.printf(text, x, y, limit, align, r, sx, sy, ox, oy, kx, ky)
		local m, g, b, a = love.graphics.getColor()
		flushSpriteBatch()
		rendering.text:addf({{m, g, b, a}, text}, limit, align, x, y, r, sx, sy, ox, oy, kx, ky)
	end

	function rendering.setColor(r, g, b, a)
		return rendering.spriteBatch:setColor(r, g, b, a)
	end

	function rendering.draw(drawable, ...)
		flushText()
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
			return love.graphics.draw(drawable, ...)
		end
	end

	function rendering.flush()
		-- Only one of them should trigger.
		flushSpriteBatch()
		flushText()
	end
end

return rendering
