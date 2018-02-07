-- AquaShine Node system, intended to replace Composition
-- Doesn't support rotation unfortunately
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local love = require("love")
local Node = AquaShine.Class("AquaShine.Node")

---------------------
-- Base node class --
---------------------

function Node.init(this, brother, parent)
	if brother then
		assert(brother:instanceOf(Node), "bad argument #3 to 'AquaShine.Node' (AquaShine.Node expected)")
	end
	
	if parent then
		assert(parent:instanceOf(Node), "bad argument #4 to 'AquaShine.Node' (AquaShine.Node expected)")
	end
	
	this.parent = parent
	this.brother = brother
	this.child = {}
	this.events = {}
	this.userdata = {}
	this.x = 0
	this.y = 0
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
	for i = 1, #this.child do
		love.graphics.push("all")
		this.child[i]:draw()
		love.graphics.pop()
	end
	
	-- If there's brother, pass to it next as tail call
	if this.brother then
		return this.brother:draw()
	end
end

function Node.setEventHandler(this, name, func)
	this.events[name] = func
end

function Node.triggerEvent(this, name, ...)
	if this.events[name] and this.events[name](this, select(1, ...)) then
		return
	end
	
	-- Nothing to do. Pass it to child if any
	for i = 1, #this.child do
		if this.child[i]:triggerEvent(name, select(1, ...)) then
			break
		end
	end
	
	-- If there's brother, pass to it next as tail call
	if this.brother then
		return this.brother:triggerEvent(name, select(1, ...))
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
	
	return this
end

function Node.setBrother(this, node)
	this.brother = assert(node:instanceOf(Node) and node, "bad argument #1 to 'Node.setBrother' (AquaShine.Node expected)")
	return this
end

function Node.addChild(this, node)
	this.child[#this.child + 1] = assert(node:instanceOf(Node) and node, "bad argument #1 to 'Node.setBrother' (AquaShine.Node expected)")
	return this
end

--------------------
-- Colorable node --
--------------------
local ColorNode = Node:extend("AquaShine.Node.Colorable")

function ColorNode.init(this, ...)
	this.color = {1, 1, 1, 1}
	
	return Node.init(this, ...)
end

function ColorNode.setColor(this, r, g, b, a)
	this.color[1] = assert(type(r) == "number" and r, "bad argument #1 to 'AquaShine.Node.Colorable:setColor' (number expected)")
	this.color[2] = assert(type(r) == "number" and g, "bad argument #2 to 'AquaShine.Node.Colorable:setColor' (number expected)")
	this.color[3] = assert(type(r) == "number" and b, "bad argument #3 to 'AquaShine.Node.Colorable:setColor' (number expected)")
	this.color[4] = type(a) == "number" and a or 1
	return this
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

function ImageNode.init(this, image, b, p)
	if type(image) == "userdata" and image:typeOf("Drawable") then
		this.image = image
	else
		this.image = AquaShine.LoadImage(image)
	end
	
	return ColorNode.init(this, b, p)
end

function ImageNode.draw(this)
	love.graphics.setColor(this.color)
	love.graphics.draw(this.image, this.x, this.y)
	
	return ColorNode.draw(this)
end

-------------------------------
-- Utilities Macro Functions --
-------------------------------
local Util = {}

function Util.SingleTouchOnly(node, actionpressed, actionreleased, actionmoved)
	node.userdata.singletouch = nil
	
	-- Function initialization
	if actionpressed then
		node.events.MousePressed = function(node, x, y, button, istouch)
			if node.userdata.singletouch ~= nil then
				return true
			end
			
			node.userdata.singletouch = istouch
			return actionpressed(node, x, y, button, istouch)
		end
	end
	
	if actionreleased then
		node.events.MouseReleased = function(node, x, y, button, istouch)
			if node.userdata.singletouch == istouch then
				node.userdata.singletouch = nil
				return actionreleased(x, y, button, istouch)
			end
			
			return true
		end
	end
	
	if actionmoved then
		node.events.MouseReleased = function(node, x, y, dx, dy, istouch)
			if node.userdata.singletouch == istouch then
				return actionmoved(node, x, y, dx, dy, istouch)
			end
			
			return true
		end
	end
end

function Util.InitializeInArea(node, x, y, w, h)
	-- if w and h is nil
	if w == nil and h == nil then
		node.userdata.inarea = {type = "relative", w = x, h = y}
	else
		node.userdata.inarea = {type = "absolute", x = x, y = y, w = w, h = h}
	end
end

local function inAreaFunc(x, y, x1, y1, x2, y2)
	return x >= x1 and y >= y1 and x < x2 and y < y2
end

function Util.InAreaFunction(node, action, notin)
	-- Meant to be used in mouse* events
	local inarea = assert(node.userdata.inarea, "Call InitializeIsInArea first")
	
	if inarea.type == "absolute" then
		return function(node, mx, my, ...)
			local inarea = assert(node.userdata.inarea, "Call InitializeIsInArea first")
			
			if inAreaFunc(mx, my, inarea.x, inarea.y, inarea.x + inarea.w, inarea.y + inarea.h) == not(notin) then
				return action(node, mx, my, select(1, ...))
			else
				return false
			end
		end
	elseif inarea.type == "relative" then
		return function(node, mx, my, ...)
			local inarea = assert(node.userdata.inarea, "Call InitializeIsInArea first")
			
			if inAreaFunc(mx, my, node.x, node.y, node.x + inarea.w, node.y + inarea.h) == not(notin) then
				return action(node, mx, my, select(1, ...))
			else
				return false
			end
		end
	end
end

----------------
-- Set module --
----------------

-- Base node
Node.Colorable = ColorNode
Node.Rectangle = RectNode
Node.Image = ImageNode
Node.Util = Util

-- Set AquaShine variable
AquaShine.Node = Node
