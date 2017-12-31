-- AquaShine Composition Drawing system
-- Part of AquaShine loader
-- See copyright notice in AquaShine.lua

local AquaShine = ...
local love = love
local Composition = {}
local comp_mt = {__index = Composition}
local noop = function() end

--[[
local _example = {
	x = 0,								-- Position. Defaults to 0
	y = 0,
	w = 50,								-- Width. Defaults to nil. Used for mouse detection
	h = 50,
	update = function(this, deltaT)		-- Update function. Optional
	end,
	draw = function(this) end,			-- Draw function. Mandatory. Position is translated to x and y
	draw_hv = function(this) end,		-- Draw function (on mouse hover). Optional. Defaults same to draw function
	draw_se = function(this) end,		-- Draw function (on mouse clicking selected). Optional. Defaults same to draw function
	click = function(this, x, y) end,	-- Mouse click function. Optional.
}
]]

----------------------
-- Composition Main --
----------------------

function Composition.Create(list)
	local this = {}
	-- format: component index, x, y, click
	this.mousedata = {nil, 0, 0, false}
	this.list = list or {}
	
	return setmetatable(this, comp_mt)
end

function Composition.Add(this, obj)
	this.list[#this.list + 1] = obj
	return this
end

function Composition.AddFirst(this, obj)
	table.insert(this.list, 1, obj)
	return this
end

function Composition.Remove(this)
	this.list[#this.list] = nil
	return this
end

function Composition.RemoveFirst(this)
	table.remove(this.list, 1)
	return this
end

function Composition.Update(this, deltaT)
	for i = 1, #this.list do
		local a = this.list[i]
		
		if a.update then
			a:update(deltaT)
		end
	end
end

function Composition.Draw(this)
	love.graphics.push("all")
	
	for i = 1, #this.list do
		local a = this.list[i]
		local drawf = a.draw
		local x, y = a.x or 0, a.y or 0
		
		if this.mousedata[1] == i then
			drawf = a.draw_se or drawf
		elseif (a.w and a.h) and
			this.mousedata[2] >= x and this.mousedata[3] >= y and
			this.mousedata[2] < x + a.w and this.mousedata[3] < y + a.h
		then
			drawf = a.draw_hv or drawf
		end
		
		love.graphics.translate(x, y)
		drawf(a)
		love.graphics.translate(-x, -y)
	end
	
	love.graphics.pop()
end

function Composition.MousePressed(this, x, y)
	this.mousedata[2], this.mousedata[3] = x, y
	
	for i = 1, #this.list do
		local a = this.list[i]
		
		if (a.w and a.h) and
			x >= a.x and y >= a.y and
			x < a.x + a.w and y < a.y + a.h
		then
			this.mousedata[1] = i
			return true
		end
	end
	
	return false
end

function Composition.MouseMoved(this, x, y)
	this.mousedata[2], this.mousedata[3] = x, y
	
	if this.mousedata[1] then
		local a = assert(this.list[this.mousedata[1]])
		
		if x >= a.x and y >= a.y and
		   x < a.x + a.w and y < a.y + a.h
		then
			return true
		end
		
		this.mousedata[1] = nil
	end
	
	return false
end

function Composition.MouseReleased(this, x, y)
	this.mousedata[2], this.mousedata[3] = x, y
	
	if this.mousedata[1] then
		local a = assert(this.list[this.mousedata[1]])
		
		if (a.w and a.h) and a.click and
			x >= a.x and y >= a.y and
			x < a.x + a.w and y < a.y + a.h
		then
			a:click(x, y)
			this.mousedata[1] = nil
			return true
		end
	end
	
	this.mousedata[1] = nil
	return false
end

function Composition.Wrap(this, load_func, additional)
	local a = {
		Start = load_func or noop,
		Update = function(deltaT) this:Update(deltaT) end,
		Draw = function() this:Draw() end,
		MousePressed = function(x, y) this:MousePressed(x, y) end,
		MouseMoved = function(x, y) this:MouseMoved(x, y) end,
		MouseReleased = function(x, y) this:MouseReleased(x, y) end,
	}
	
	if additional then
		for n, v in pairs(additional) do
			a[n] = v
		end
	end
	
	return a
end

--------------------------
-- Composition Template --
--------------------------
local Template = {}

local function override(t1, t2)
	if t2 then
		for n, v in pairs(t2) do
			t1[n] = v
		end
	end
	
	return t1
end

local function draw_image(this)
	love.graphics.setColor(1, 1, 1)
	love.graphics.draw(this.image)
end

local function draw_text(this)
	love.graphics.setColor(this.color)
	love.graphics.setFont(this.font)
	love.graphics.print(this.text)
end

function Template.Image(img, x, y, lw, ovrd)
	local a = {}
	a.x, a.y = x, y
	
	if lw then
		a.w, a.h = img:getDimensions()
	end
	
	a.image = img
	a.draw = draw_image
	
	return override(a, ovrd)
end

function Template.Text(font, text, x, y, r, g, b, a, ovrd)
	local z = {}
	z.x, z.y = x, y
	
	z.font = font
	z.text = text
	z.color = {r, g, b, a}
	z.draw = draw_text
	
	return override(z, ovrd)
end

Composition.Template = Template
AquaShine.Composition = Composition
