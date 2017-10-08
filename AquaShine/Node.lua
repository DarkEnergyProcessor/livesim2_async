-- AquaShine Node system, intended to replace Composition
-- Doesn't support rotation unfortunately
-- Part of Live Simulator: 2
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local love = require("love")
local class = require("30log")
local Node = class("AquaShine.Node")

---------------------
-- Base node class --
---------------------

function Node.init(this, x, y, brother, parent)
	if brother then
		assert(getmetatable(brother) == Node, "bad argument #3 to 'AquaShine.Node' (AquaShine.Node expected)")
	end
	
	if parent then
		assert(getmetatable(parent) == Node, "bad argument #4 to 'AquaShine.Node' (AquaShine.Node expected)")
	end
	
	this.parent = parent
	this.brother = brother
	this.child = {}
	this.x = this.x or 0
	this.y = this.y or 0
end

function Node.update(this, deltaT)
	-- Nothing to do. Pass it to child if any
	for i = 1, #this.child do
		this.child[i]:update(deltaT)
	end
	
	-- If there's brother, pass to it next as tail call
	if this.brother then
		return this.brother:update(deltaT)
	end
end

function Node.draw(this)
	-- Nothing to do. Pass it to child if any
	love.graphics.translate(this.x, this.y)
	for i = 1, #this.child do
		love.graphics.push("all")
		this.child[i]:draw()
		love.graphics.pop()
	end
	love.graphics.translate(-this.x, -this.y)
	
	-- If there's brother, pass to it next as tail call
	if this.brother then
		return this.brother:draw()
	end
end

function Node.getPosition(this)
	return this.x, this.y
end

function Node.setPosition(this, x, y)
	if type(x) == "number" then
		this.x = x
	end
	
	if type(y) == "number" then
		this.y = y
	end
end

--------------------
-- Colorable node --
--------------------
local ColorNode = Node:extend("AquaShine.Node.Colorable")

function ColorNode.init(this, ...)
	this.color = {255, 255, 255, 255}
	
	return Node.init(this, ...)
end

function ColorNode.setColor(this, r, g, b, a)
	this.color[1] = assert(type(r) == "number", "bad argument #1 to 'AquaShine.Node.Colorable:setColor' (number expected)")
	this.color[2] = assert(type(r) == "number", "bad argument #2 to 'AquaShine.Node.Colorable:setColor' (number expected)")
	this.color[3] = assert(type(r) == "number", "bad argument #3 to 'AquaShine.Node.Colorable:setColor' (number expected)")
	this.color[4] = type(a) == "number" and a or 255
end

function ColorNode.getColor(this)
	return this.color[1], this.color[2], this.color[3], this.color[4]
end

--------------------
-- Rectangle node --
--------------------
local RectNode = ColorNode:extend("AquaShine.Node.Rect")

function RectNode.init(this, mode, x, y, w, h, b, p)
	this.mode = assert(mode == "fill" or mode == "line", "bad argument #1 to 'AquaShine.Node.Rectangle' (invalid rectangle mode)")
	this.width = assert(type(w) == "number", "bad argument #4 to 'AquaShine.Node.Rectangle' (number expected)")
	this.height = assert(type(h) == "number", "bad argument #5 to 'AquaShine.Node.Rectangle' (number expected)")
	
	return ColorNode.init(this, x, y, b, p)
end

function RectNode.draw(this)
	love.graphics.setColor(this.color)
	love.graphics.rectangle(this.mode, this.x, this.y, this.w, this.h)
	
	return Node.draw(this)
end

----------------
-- Image node --
----------------
local ImageNode = ColorNode:extend("AquaShine.Node.Image")

function ImageNode.init(this, x, y, image, b, p)
	if type(image) == "userdata" and image:typeOf("Drawable") then
		this.image = image
	else
		this.image = AquaShine.LoadImage(image)
	end
	
	return ColorNode.init(this, x, y, b, p)
end

function ImageNode.draw(this)
	love.graphics.draw(this.image, this.x, this.y)
	
	return Node.draw(this)
end

----------------
-- Set module --
----------------

Node.Colorable = ColorNode
Node.Rectangle = RectNode
Node.Image = ImageNode
AquaShine.Node = Node
