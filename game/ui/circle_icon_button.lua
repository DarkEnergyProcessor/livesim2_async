-- Icon-only circle buttin
-- Part of Live Simulator: 2
-- See copyright notice into main.lua

local love = require("love")
local Luaoop = require("libs.Luaoop")

local color = require("color")
local Util = require("util")

local Glow = require("game.afterglow")
local Ripple = require("game.ui.ripple")

local CircleIconButton = Luaoop.class("Livesim2.CircleIconButton", Glow.Element)

local function createCircleMesh(r1, r2, segment)
	segment = segment or (360 * math.max(360 / r1, 1))
	assert(segment >= 3, "invalid segment count")

	local points = {}
	for i = 1, segment do
		local angle = (i - 1) / segment * 2 * math.pi
		local c, s = math.cos(angle), math.sin(angle)
		points[#points + 1] = {c * r1, -s * r1, 0, 0, 1, 1, 1, 0}
		points[#points + 1] = {c * r2, -s * r2, 0, 0, 1, 1, 1, 1}
	end
	points[#points + 1] = {0, 0, 0, 0, 1, 1, 1, 1}

	local map = {}
	for i = 1, segment do
		local it = i % segment + 1
		map[#map + 1] = (i - 1) * 2 + 2
		map[#map + 1] = (i - 1) * 2 + 1
		map[#map + 1] = (it - 1) * 2 + 2
		map[#map + 1] = (it - 1) * 2 + 2
		map[#map + 1] = (i - 1) * 2 + 1
		map[#map + 1] = (it - 1) * 2 + 1
		map[#map + 1] = (i - 1) * 2 + 2
		map[#map + 1] = (it - 1) * 2 + 2
		map[#map + 1] = #points
	end

	local mesh = love.graphics.newMesh(points, "triangles", "static")
	mesh:setVertexMap(map)
	return mesh
end

function CircleIconButton:new(cc, r, i, is, ic, ir)
	self.color = cc
	self:setImage(i, is, ic)
	self.radius = r
	self.rotation = ir or 0
	self.width, self.height = 2 * r, 2 * r
	self.isPressed = false
	self.ripple = Ripple(2 * r)
	self.x, self.y = 0, 0
	self.stencilFunc = function()
		return love.graphics.circle("fill", self.x + self.radius, self.y + self.radius, self.radius)
	end

	self:addEventListener("mousepressed", CircleIconButton._pressed)
	self:addEventListener("mousereleased", CircleIconButton._released)
	self:addEventListener("mousecanceled", CircleIconButton._released)
end

function CircleIconButton:setImage(i, is, ic)
	if i then
		self.image = i
		self.imageScale = is or 1
		self.imageColor = ic or color.white
		self.imageW, self.imageH = i:getDimensions()
	else
		self.image = nil
		self.imageScale = 0
		self.imageColor = color.white
		self.imageW, self.imageH = 0, 0
	end
end

function CircleIconButton:update(dt)
	self.ripple:update(dt)
end

-- angle 0...2pi -> up, right, bottom, left
function CircleIconButton:setShadow(r2, angle, offset)
	if r2 == nil then
		self.shadow = nil
	else
		assert(r2 < self.radius, "invalid strength")
		local c, s = math.cos(angle), math.sin(angle)
		self.shadow = createCircleMesh(self.radius, r2, 360)
		self.shadowOffX = s * offset
		self.shadowOffY = -c * offset
	end
end

function CircleIconButton:_pressed(_, x, y)
	if Util.distance(x, y, self.radius, self.radius) <= self.radius then
		self.isPressed = true
		self.ripple:pressed(x, y)
		return false
	else
		return true
	end
end

function CircleIconButton:_released(_)
	if self.isPressed then
		self.isPressed = false
		self.ripple:released()
	else
		return true
	end
end

function CircleIconButton:render(x, y)
	x, y = x or 0, y or 0
	self.x, self.y = x, y

	if self.shadow then
		love.graphics.setColor(color.black)
		love.graphics.draw(self.shadow, x + self.radius + self.shadowOffX, y + self.radius + self.shadowOffY)
	end

	love.graphics.setColor(self.color)
	love.graphics.circle("fill", x + self.radius, y + self.radius, self.radius)
	love.graphics.circle("line", x + self.radius, y + self.radius, self.radius)

	if self.image then
		love.graphics.setColor(self.imageColor)
		love.graphics.draw(
			self.image,
			x + self.radius, y + self.radius, self.rotation,
			self.imageScale, self.imageScale,
			self.imageW * 0.5, self.imageH * 0.5
		)
	end

	if self.ripple:isActive() then
		-- Setup stencil buffer
		love.graphics.stencil(self.stencilFunc, "replace", 1, false)
		love.graphics.setStencilTest("equal", 1)
		self.ripple:draw(255, 255, 255, x, y)
		love.graphics.setStencilTest()
	end
end

return CircleIconButton
