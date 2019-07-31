-- CSS Cubic Bezier
-- Part of Live Simulator: 2, can be used as standalone library
--[[---------------------------------------------------------------------------
-- Copyright (c) 2040 Dark Energy Processor
--
-- This software is provided 'as-is', without any express or implied
-- warranty. In no event will the authors be held liable for any damages
-- arising from the use of this software.
--
-- Permission is granted to anyone to use this software for any purpose,
-- including commercial applications, and to alter it and redistribute it
-- freely, subject to the following restrictions:
--
-- 1. The origin of this software must not be misrepresented you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not
--    be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source
--    distribution.
--]]---------------------------------------------------------------------------

local abs = math.abs

local cubicBezier = {}
local cubicBezier_t = nil
local ffi = nil

local EPSILON = 1e-6

if rawget(_G, "jit") and jit.status() and package.preload.ffi then
	ffi = require("ffi")

	cubicBezier_t = ffi.typeof([[struct {
		double ax, bx, cx, ay, by, cy;
	}]])
end

function cubicBezier:__init(p0, p1, p2, p3)
	self.cx = 3.0 * p0
	self.bx = 3.0 * (p2 - p0) - self.cx
	self.ax = 1.0 - self.cx -self.bx
	self.cy = 3.0 * p1
	self.by = 3.0 * (p3 - p1) - self.cy
	self.ay = 1.0 - self.cy - self.by
end

function cubicBezier:_sx(t)
	return ((self.ax * t + self.bx) * t + self.cx) * t
end

function cubicBezier:_sdx(t)
	return (3 * self.ax * t + 2 * self.bx) * t + self.cx
end

function cubicBezier:_sy(t)
	return ((self.ay * t + self.by) * t + self.cy) * t
end

function cubicBezier:_scx(x)
	-- Try Newton's method
	local t2 = x
	for _ = 1, 10 do
		local x2 = self:_sx(t2) - x
		if abs(x2) < EPSILON then
			return t2
		end

		local d2 = self:_sdx(t2)
		if abs(d2) < EPSILON then
			break
		end

		t2 = t2 - x2 / d2
	end

	-- Try bi-section
	local t0, t1 = 0, 1
	if x < t0 then return t0 end
	if x > t1 then return t1 end
	t2 = x

	while t0 < t1 do
		local x2 = self:_sx(t2)
		if abs(x2 - x) < EPSILON then
			return t2
		end

		if x > x2 then t0 = t2
		else t1 = t2 end

		t2 = (t1 - t0) * 0.5 + t0
	end

	-- I'm done
	return t2
end

function cubicBezier:evaluate(x)
	return self:_sy(self:_scx(x))
end

-- Useful for hump.timer which accepts function as interpolator
function cubicBezier:getFunction()
	local bez = self

	return function(t)
		return bez:evaluate(t)
	end
end

cubicBezier.__call = cubicBezier.evaluate
cubicBezier.__index = cubicBezier

local __construct

if cubicBezier_t then
	function __construct(p0, p1, p2, p3)
		local v = ffi.new(cubicBezier_t)
		v:__init(p0, p1, p2, p3)
		return v
	end

	ffi.metatype(cubicBezier_t, cubicBezier)
else
	function __construct(p0, p1, p2, p3)
		local v = setmetatable({}, cubicBezier)
		v:__init(p0, p1, p2, p3)
		return v
	end
end

cubicBezier.new = __construct
setmetatable(cubicBezier, {__call = function(_, p0, p1, p2, p3)
	return __construct(p0, p1, p2, p3)
end})

return cubicBezier
