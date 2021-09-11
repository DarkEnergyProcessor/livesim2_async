-- NPad's Layouting Library, based on ConstraintLayout
--
-- Copyright (c) 2021 Miku AuahDark
--
-- Permission is hereby granted, free of charge, to any person obtaining a
-- copy of this software and associated documentation files (the "Software"),
-- to deal in the Software without restriction, including without limitation
-- the rights to use, copy, modify, merge, publish, distribute, sublicense,
-- and/or sell copies of the Software, and to permit persons to whom the
-- Software is furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in
-- all copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
-- OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
-- FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
-- DEALINGS IN THE SOFTWARE.

---@class NLay.BaseConstraint
local BaseConstraint = {}

---Compute and retrieve the top-left and the dimensions of layout.
---@param offx number
---@param offy number
---@return number,number,number,number
function BaseConstraint:get(offx, offy)
end

---@class NLay.Constraint: NLay.BaseConstraint
---@field private top NLay.BaseConstraint
---@field private left NLay.BaseConstraint
---@field private bottom NLay.BaseConstraint
---@field private right NLay.BaseConstraint
---@field private inTop boolean
---@field private inLeft boolean
---@field private inBottom boolean
---@field private inRight boolean
---@field private marginX number
---@field private marginY number
---@field private marginW number
---@field private marginH number
---@field private w number
---@field private h number
---@field private biasHorz number
---@field private biasVert number
---@field private inside NLay.Inside
---@field private forceIntoFlags boolean
---@field private cacheCounter number
---@field private cacheX number
---@field private cacheY number
---@field private cacheW number
---@field private cacheH number
---@field private userTag any
local Constraint = {}
Constraint.__index = Constraint

---@param constraint NLay.Constraint
---@param target NLay.BaseConstraint
---@return number,number,number,number
local function resolveConstraintSize(constraint, target, _cacheCounter)
	if target == constraint.inside.obj then
		return constraint.inside:_get(_cacheCounter)
	else
		return target:get(nil, nil, _cacheCounter)
	end
end

local function mix(a, b, t)
	return (1 - t) * a + t * b
end

local nextCacheCounter = 0

---@param offx number X offset (default to 0)
---@param offy number Y offset (default to 0)
function Constraint:get(offx, offy, _cacheCounter)
	if _cacheCounter == nil then
		_cacheCounter = nextCacheCounter
		nextCacheCounter = (nextCacheCounter + 1) % 1e15
	end

	if self.cacheCounter ~= _cacheCounter then
		self.cacheCounter = _cacheCounter

		if (self.left ~= nil or self.right ~= nil) and (self.top ~= nil or self.bottom ~= nil) then

			local x, y, w, h

			if self.w == -1 then
				-- Match parent
				local px, _, pw, _ = self.inside:_get(_cacheCounter)
				x, w = px, pw
			elseif self.w == 0 then
				-- Match constraint
				if self.left == nil or self.right == nil then
					error("insufficient constraint for width 0")
				end

				-- Left
				local e1x, _, e1w = resolveConstraintSize(self, self.left, _cacheCounter)
				if self.inLeft then
					x = e1x + self.marginX
				else
					x = e1x + e1w + self.marginX
				end

				-- Right
				local e2x, _, e2w = resolveConstraintSize(self, self.right, _cacheCounter)
				if self.inRight then
					w = e2x + e2w - x - self.marginW
				else
					w = e2x - x - self.marginW
				end
			else
				local l, r
				w = self.w

				if self.left then
					-- Left orientation
					local e1x, _, e1w = resolveConstraintSize(self, self.left, _cacheCounter)

					if self.inLeft then
						l = e1x + self.marginX
					else
						l = e1x + e1w + self.marginX
					end
				end

				if self.right then
					-- Right orientation
					local e2x, _, e2w = resolveConstraintSize(self, self.right, _cacheCounter)

					if self.inRight then
						r = e2x + e2w - self.marginW - w
					else
						r = e2x - self.marginW - w
					end
				end

				if l ~= nil and r ~= nil then
					-- Horizontally centered
					x = mix(l, r, self.biasHorz)
				else
					x = l or r
				end
			end

			if self.h == -1 then
				-- Match parent
				local _, py, _, ph = self.inside:_get(_cacheCounter)
				y, h = py, ph
			elseif self.h == 0 then
				-- Match constraint
				if self.bottom == nil or self.top == nil then
					error("insufficient constraint for height 0")
				end

				local e1y, _, e1h = select(2, resolveConstraintSize(self, self.top, _cacheCounter))

				if self.inTop then
					y = e1y + self.marginY
				else
					y = e1y + e1h + self.marginY
				end

				local e2y, _, e2h = select(2, resolveConstraintSize(self, self.bottom, _cacheCounter))

				if self.inBottom then
					h = e2y + e2h - y - self.marginH
				else
					h = e2y - y - self.marginH
				end
			else
				local t, b
				h = self.h

				if self.top then
					-- Top orientation
					local e1y, _, e1h = select(2, resolveConstraintSize(self, self.top, _cacheCounter))

					if self.inTop then
						t = e1y + self.marginY
					else
						t = e1y + e1h + self.marginY
					end
				end

				if self.bottom then
					-- Bottom orientation
					local e2y, _, e2h = select(2, resolveConstraintSize(self, self.bottom, _cacheCounter))

					if self.inBottom then
						b = e2y + e2h - self.marginH - h
					else
						b = e2y - self.marginH - h
					end
				end

				if t ~= nil and b ~= nil then
					-- Vertically centered
					y = mix(t, b, self.biasVert)
				else
					y = t or b
				end
			end

			assert(x and y and w and h, "fatal error please report!")
			self.cacheX, self.cacheY, self.cacheW, self.cacheH = x, y, w, h
		else
			error("insufficient constraint")
		end
	end

	return self.cacheX + (offx or 0), self.cacheY + (offy or 0), self.cacheW, self.cacheH
end

function Constraint:_overrideIntoFlags()
	if self.top == self.bottom and self.top ~= nil then
		self.inTop = true
		self.inBottom = true
	end

	if self.left == self.right and self.left ~= nil then
		self.inLeft = true
		self.inRight = true
	end
end

---This function tells that for constraint specified at {top,left,bottom,right}, it should NOT use the opposite sides
---of the constraint. This mainly used to prevent ambiguity.
---@param top boolean
---@param left boolean
---@param bottom boolean
---@param right boolean
---@return NLay.Constraint
function Constraint:into(top, left, bottom, right)
	self.inTop = not not top
	self.inLeft = not not left
	self.inBottom = not not bottom
	self.inRight = not not right

	if not self.forceIntoFlags then
		self:_overrideIntoFlags()
	end

	return self
end

---Set the constraint margin
---@param margin number|number[] Either number to apply all margins or table {top, left, bottom, right} margin.
---Defaults to 0 for absent/nil values.
---@return NLay.Constraint
function Constraint:margin(margin)
	margin = margin or 0

	if type(margin) == "number" then
		self.marginX, self.marginY, self.marginW, self.marginH = margin, margin, margin, margin
	else
		self.marginX = margin[2] or 0
		self.marginY = margin[1] or 0
		self.marginW = margin[4] or 0
		self.marginH = margin[3] or 0
	end

	return self
end

---Set the size of constraint. If width/height is 0, it will calculate it based on the other connected constraint.
---If it's -1, then it will use parent's width/height minus padding.
---@param width number Constraint width.
---@param height number Constraint height.
---@return NLay.Constraint
function Constraint:size(width, height)
	assert(width >= 0 or width == -1, "invalid width")
	assert(height >= 0 or height == -1, "invalid height")
	self.w, self.h = width, height

	return self
end

---Set the constraint bias. By default, for fixed width/height, the position are centered around (bias 0.5).
---@param horz number Horizontal bias, real value between 0..1 inclusive.
---@param vert number Vertical bias, real value between 0..1 inclusive.
---@return NLay.Constraint
function Constraint:bias(horz, vert)
	if horz then
		self.biasHorz = math.min(math.max(horz, 0), 1)
	end

	if vert then
		self.biasVert = math.min(math.max(vert, 0), 1)
	end

	return self
end

---Force the "into" flags to be determined by user even if it may result as invalid constraint.
---This function is used for some "niche" cases. You don't have to use this almost all the time.
---@param force boolean
---@return NLay.Constraint
function Constraint:forceIn(force)
	self.forceIntoFlags = not not force
	return self
end

---Tag this constraint with some userdata, like an id, for example.
---Useful to keep track of constraints when they're rebuilt.
---@param userdata any
---@return NLay.Constraint
function Constraint:tag(userdata)
	self.userTag = userdata
	return self
end

---@return any
function Constraint:getTag()
	return self.userTag
end

---@class NLay.MaxConstraint: NLay.BaseConstraint
---@field private list NLay.BaseConstraint[]
local MaxConstraint = {}
MaxConstraint.__index = MaxConstraint

---@param offx number X offset (default to 0)
---@param offy number Y offset (default to 0)
---@return number,number,number,number
function MaxConstraint:get(offx, offy, _cacheCounter)
	local minx, miny, maxx, maxy = self.list[1]:get(nil, nil, _cacheCounter)
	maxx = maxx + minx
	maxy = maxy + miny

	for i = 2, #self.list do
		local x, y, w, h = self.list[i]:get(nil, nil, _cacheCounter)
		minx = math.min(minx, x)
		miny = math.min(miny, y)
		maxx = math.max(maxx, x + w)
		maxy = math.max(maxy, y + h)
	end

	return minx + (offx or 0), miny + (offy or 0), maxx - minx, maxy - miny
end

---@class NLay.LineConstraint: NLay.BaseConstraint
---@field private constraint NLay.BaseConstraint | NLay.Inside
---@field private direction '"horizontal"' | '"vertical"'
---@field private mode '"percent"' | '"pixel"'
---@field private offset number
---@field private flip boolean
local LineConstraint = {}
LineConstraint.__index = LineConstraint

function LineConstraint:get(offx, offy, _cacheCounter)
	offx, offy = offx or 0, offy or 0
	local x, y, w, h

	if self.constraint.obj then
		x, y, w, h = self.constraint:_get(_cacheCounter)
	else
		x, y, w, h = self.constraint:get(nil, nil, _cacheCounter)
	end

	if self.direction == "horizontal" then
		-- Vertical line for horizontal constraint
		if self.mode == "percent" then
			-- Interpolate
			return mix(x, x + w, (self.flip and 1 or 0) + self.offset) + offx, y + offy, 0, h
		else
			-- Offset
			return x + (self.flip and w or 0) + self.offset + offx, y + offy, 0, h
		end
	else
		-- Horizontal line for vertical constraint
		if self.mode == "percent" then
			-- Interpolate
			return x + offx, mix(y, y + h, (self.flip and 1 or 0) + self.offset) + offy, w, 0
		else
			-- Offset
			return x + offx, y + (self.flip and h or 0) + self.offset + offy, w, 0
		end
	end

	error("fatal error unreachable code")
end

---This class is not particularly useful other than creating new `NLay.Constraint` object.
---However it's probably better to cache this object if lots of same constraint creation is done with same
---"inside" parameters
---@class NLay.Inside
---@field private obj NLay.BaseConstraint
---@field private pad number[]
local Inside = {}
Inside.__index = Inside

---Create new `NLay.Constraint` object.
---@param top NLay.BaseConstraint
---@param left NLay.BaseConstraint
---@param bottom NLay.BaseConstraint
---@param right NLay.BaseConstraint
---@return NLay.Constraint
function Inside:constraint(top, left, bottom, right)
	local result = setmetatable({
		top = top,
		left = left,
		bottom = bottom,
		right = right,
		inTop = top == self.obj,
		inLeft = left == self.obj,
		inBottom = bottom == self.obj,
		inRight = right == self.obj,
		marginX = 0,
		marginY = 0,
		marginW = 0,
		marginH = 0,
		w = -1,
		h = -1,
		biasHorz = 0.5,
		biasVert = 0.5,
		inside = self,
		forceIntoFlags = false,
		cacheCounter = -1,
		cacheX = 0,
		cacheY = 0,
		cacheW = 0,
		cacheH = 0,
	}, Constraint)

	-- Deduce "into" flags
	result:_overrideIntoFlags()

	return result
end

---@return number,number,number,number
function Inside:_get(_cacheCounter)
	local x, y, w, h = self.obj:get(nil, nil, _cacheCounter)
	return x + self.pad[2], y + self.pad[1], w - self.pad[4] - self.pad[2], h - self.pad[3] - self.pad[1]
end

---@class NLay.RootConstraint: NLay.BaseConstraint
local RootConstraint = {}
RootConstraint.__index = RootConstraint
RootConstraint.x = 0
RootConstraint.y = 0
RootConstraint.width = 800
RootConstraint.height = 600
RootConstraint._VERSION = "1.1.1"
RootConstraint._AUTHOR = "MikuAuahDark"
RootConstraint._LICENSE = "MIT"

---@param offx number X offset (default to 0)
---@param offy number Y offset (default to 0)
---@return number,number,number,number
function RootConstraint:get(offx, offy)
	return RootConstraint.x + (offx or 0), RootConstraint.y + (offy or 0), RootConstraint.width, RootConstraint.height
end

---Update the game window dimensions. Normally all return values from `love.window.getSafeArea` should be passed.
---@param x number
---@param y number
---@param w number
---@param h number
function RootConstraint.update(x, y, w, h)
	if
		RootConstraint.x ~= x or
		RootConstraint.y ~= y or
		RootConstraint.width ~= w or
		RootConstraint.height ~= h
	then
		RootConstraint.x, RootConstraint.y, RootConstraint.width, RootConstraint.height = x, y, w, h
	end
end

---Create new `NLay.Inside` object used to construct `NLay.Constraint`.
---@param object NLay.BaseConstraint
---@param padding number|number[]
---@return NLay.Inside
function RootConstraint.inside(object, padding)
	padding = padding or 0

	-- Copy padding values
	local tabpad
	if type(padding) == "number" then
		tabpad = {padding, padding, padding, padding}
	else
		tabpad = {0, 0, 0, 0}
		for i = 1, 4 do
			tabpad[i] = padding[i] or 0
		end
	end

	-- TODO check if padding values were correct?
	return setmetatable({
		obj = object,
		pad = tabpad
	}, Inside)
end

---Create new constraint whose the size and the position is based on bounding box of the other constraint.
---@vararg NLay.BaseConstraint
---@return NLay.MaxConstraint
function RootConstraint.max(...)
	local list = {...}
	assert(#list > 1, "need at least 2 constraint")

	return setmetatable({
		list = list
	}, MaxConstraint)
end

---Create new guideline constraint. Horizontal direction creates vertical line with width of 0 for constraint to
---attach horizontally. Vertical direction creates horizontal line with height of 0 for constraint to attach
---vertically.
---@param constraint NLay.BaseConstraint | NLay.Inside
---@param direction '"horizontal"' | '"vertical"'
---@param mode '"percent"' | '"pixel"'
---@param offset number
---@return NLay.LineConstraint
function RootConstraint.line(constraint, direction, mode, offset)
	if direction ~= "horizontal" and direction ~= "vertical" then
		error("invalid direction")
	end

	if mode ~= "percent" and mode ~= "pixel" then
		error("invalid mode")
	end

	return setmetatable({
		constraint = constraint,
		direction = direction,
		mode = mode,
		offset = offset,
		flip = 1/offset < 0
	}, LineConstraint)
end

return RootConstraint

--[[
Changelog:

v1.1.1: 2021-07-12
> Fixed Constraint:tag not working.

v1.1.0: 2021-07-11
> Added guideline constraint, created with NLay.line function.
> Added constraint tagging.

v1.0.4: 2021-06-27
> Implemented per-`:get()` value caching.

v1.0.3: 2021-06-25
> Added "Constraint:forceIn" function.

v1.0.2: 2021-06-23
> Added "offset" parameter to BaseConstraint:get()

v1.0.1: 2021-06-16
> Bug fixes on certain constraint combination.
> Added "bias" feature.

v1.0.0: 2021-06-15
> Initial release.
]]
