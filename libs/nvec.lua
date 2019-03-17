-- hump.vector compatible FFI-accelerated 2D vector library
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
-- 1. The origin of this software must not be misrepresented; you must not
--    claim that you wrote the original software. If you use this software
--    in a product, an acknowledgment in the product documentation would be
--    appreciated but is not required.
-- 2. Altered source versions must be plainly marked as such, and must not
--    be misrepresented as being the original software.
-- 3. This notice may not be removed or altered from any source
--    distribution.
--]]---------------------------------------------------------------------------

local type = type
local sin, cos, atan2 = math.sin, math.cos, (math.atan2 or math.atan)
local sqrt, rnd = math.sqrt, math.random
local ffi = nil

local nvec, nvec_t = {}, nil
local __construct, isVector

if rawget(_G, "jit") and jit.status() and package.preload.ffi then
	-- FFI-accelerated version
	ffi = require("ffi")
	nvec_t = ffi.typeof("struct {double x, y;}")

	function __construct(x, y)
		return nvec_t(x or 0, y or 0)
	end

	function isVector(a)
		-- NEVER USE tostring(ctype) FOR CDATA TYPE COMPARISON!
		return type(a) == "cdata" and ffi.istype(a, nvec_t)
	end
else
	function __construct(x, y)
		return setmetatable({x = x or 0, y = y or 0}, nvec)
	end

	function isVector(a)
		return getmetatable(a) == nvec
	end
end

function nvec.fromPolar(angle, radius)
	radius = radius or 1
	return __construct(cos(angle) * radius, sin(angle) * radius)
end

function nvec.randomDirection(min, max)
	min = min or 1
	max = max or min
	assert(max > 0, "max length must be greater than zero")
	assert(max >= min, "max length must be greater than or equal to min length")
	return nvec.fromPolar(rnd() * 2*math.pi, rnd() * (max - min) + min)
end

function nvec:clone()
	return __construct(self.x, self.y)
end

function nvec:unpack()
	return self.x, self.y
end

function nvec:__tostring()
	-- prefer string.format over concatenation for
	-- optimization purpose in LuaJIT 2.1
	return string.format("(%.14g,%.14g)", self:unpack())
end

function nvec:__unm()
	return __construct(-self.x, -self.y)
end

function nvec.__add(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	return __construct(a.x + b.x, a.y + b.y)
end

function nvec.__sub(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	return __construct(a.x - b.x, a.y - b.y)
end

function nvec.__mul(a, b)
	if type(a) == "number" then
		return __construct(b.x * a, b.y * a)
	elseif type(b) == "number" then
		return __construct(a.x * b, a.y * b)
	else
		assert(isVector(a) and isVector(b), "NVec expected")
		return a.x * b.x + a.y * b.y
	end
end

function nvec.__div(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	return __construct(a.x / b.x, a.y / b.y)
end

function nvec.__eq(a, b)
	return a.x == b.x and a.y == b.y
end

function nvec.__lt(a, b)
	return a.x < b.x or (a.x == b.x and a.y < b.y)
end

function nvec.__le(a, b)
	return a.x <= b.x and a.y <= b.y
end

function nvec.dot(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	return a.x * b.x + a.y * b.y
end

function nvec.permul(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	return __construct(a.x * b.x, a.y * b.y)
end

function nvec:toPolar()
	return __construct(atan2(self.x, self.y), self:len())
end

function nvec:len2()
	return self.x * self.x + self.y * self.y
end

function nvec:len()
	return sqrt(self.x * self.x + self.y * self.y)
end

function nvec.dist2(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	local c, d = a.x - b.x, a.y - b.y
	return c * c + d * d
end

function nvec.dist(a, b)
	assert(isVector(a) and isVector(b), "NVec expected")
	local c, d = a.x - b.x, a.y - b.y
	return sqrt(c * c + d * d)
end

function nvec:normalizeInplace()
	local l = sqrt(self.x * self.x + self.y * self.y)
	if l > 0 then
		self.x, self.y = self.x / l, self.y / l
	end
	return self
end

function nvec:normalized()
	return self:clone():normalizeInplace()
end
nvec.normalize = nvec.normalized

function nvec:rotateInplace(angle)
	local c, s = cos(angle), sin(angle)
	self.x, self.y = c * self.x - s * self.y, s * self.x + c * self.y
	return self
end

function nvec:rotate(angle)
	return self:clone():rotateInplace(angle)
end
nvec.rotated = nvec.rotate

function nvec:perpendicular()
	return __construct(-self.y, self.x)
end

function nvec:projectOn(v)
	assert(isVector(v), "NVec expected")
	-- (self * v) * v / v:len2()
	local s = (self.x * v.x + self.y * v.y) / (v.x * v.x + v.y * v.y)
	return __construct(s * v.x, s * v.y)
end

function nvec:mirrorOn(v)
	assert(isVector(v), "NVec expected")
	-- 2 * self:projectOn(v) - self
	local s = 2 * (self.x * v.x + self.y * v.y) / (v.x * v.x + v.y * v.y)
	return __construct(s * v.x - self.x, s * v.y - self.y)
end

function nvec:cross(v)
	assert(isVector(v), "NVec expected")
	return self.x * v.y - self.y * v.x
end

function nvec:trimInplace(maxLen)
	local s = maxLen * maxLen / (self.x * self.x + self.y * self.y)
	s = (s > 1 and 1) or sqrt(s)
	self.x, self.y = self.x * s, self.y * s
	return self
end

function nvec:trim(maxLen)
	return self:clone():trimInplace(maxLen)
end
nvec.trimmed = nvec.trin

function nvec:angleTo(other)
	if other then
		return atan2(self.y, self.x) - atan2(other.y, other.x)
	end
	return atan2(self.y, self.x)
end

nvec.new = __construct
nvec.__index = nvec

-- FFI metatype set for FFI accelerated version
if nvec_t then
	ffi.metatype(nvec_t, nvec)
end

setmetatable(nvec, {
	__call = function(_, x, y)
		return __construct(x, y)
	end
})

return nvec
