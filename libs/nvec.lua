-- hump.vector compatible FFI-accelerated 2D vector library
-- Part of Live Simulator: 2, can be used as standalone library
--[[---------------------------------------------------------------------------
-- Copyright (c) 2020 Miku AuahDark
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
--]]---------------------------------------------------------------------------

local type = type
local sin, cos, atan2 = math.sin, math.cos, (math.atan2 or math.atan)
local sqrt, rnd, pi = math.sqrt, math.random, math.pi
local ffi = nil

---@class NVec
local nvec = {}
local nvec_t = nil
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

---@param angle number
---@param radius number
---@return NVec
function nvec.fromPolar(angle, radius)
	radius = radius or 1
	return __construct(cos(angle) * radius, sin(angle) * radius)
end

---@param min number
---@param max number
---@return NVec
function nvec.randomDirection(min, max)
	min = min or 1
	max = max or min
	assert(max > 0, "max length must be greater than zero")
	assert(max >= min, "max length must be greater than or equal to min length")
	return nvec.fromPolar(rnd() * 2*pi, rnd() * (max - min) + min)
end

---@return NVec
function nvec:clone()
	return __construct(self.x, self.y)
end

---@return number,number
function nvec:unpack()
	return self.x, self.y
end

---@return string
function nvec:__tostring()
	-- prefer string.format over concatenation for
	-- optimization purpose in LuaJIT 2.1
	return string.format("(%.14g,%.14g)", self:unpack())
end

---@return NVec
function nvec:__unm()
	return __construct(-self.x, -self.y)
end

---@param b NVec
---@return NVec
function nvec:__add(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	return __construct(self.x + b.x, self.y + b.y)
end

---@param b NVec
---@return NVec
function nvec:__sub(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	return __construct(self.x - b.x, self.y - b.y)
end

---@param b number|NVec
---@return number|NVec
function nvec:__mul(b)
	if type(self) == "number" then
		return __construct(b.x * self, b.y * self)
	elseif type(b) == "number" then
		return __construct(self.x * b, self.y * b)
	else
		assert(isVector(self) and isVector(b), "NVec expected")
		return self.x * b.x + self.y * b.y
	end
end

---@param b NVec
---@return NVec
function nvec:__div(b)
	assert(isVector(self), "NVec expected")

	if isVector(b) then
		return __construct(self.x / b.x, self.y / b.y)
	else
		return __construct(self.x / b, self.y / b)
	end
end

---@param b NVec
function nvec:__eq(b)
	return isVector(self) and isVector(b) and self.x == b.x and self.y == b.y
end

---@param b NVec
function nvec:__lt(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	return self.x < b.x or (self.x == b.x and self.y < b.y)
end

---@param b NVec
function nvec:__le(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	return self.x <= b.x and self.y <= b.y
end

---@param b NVec
---@return number
function nvec:dot(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	return self.x * b.x + self.y * b.y
end

---@param b NVec
---@return NVec
function nvec:permul(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	return __construct(self.x * b.x, self.y * b.y)
end

---@return NVec
function nvec:toPolar()
	return __construct(atan2(self.x, self.y), self:len())
end

---@return number
function nvec:len2()
	return self.x * self.x + self.y * self.y
end

---@return number
function nvec:len()
	return sqrt(self.x * self.x + self.y * self.y)
end

---@param b NVec
---@return number
function nvec:dist2(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	local c, d = self.x - b.x, self.y - b.y
	return c * c + d * d
end

---@param b NVec
---@return number
function nvec:dist(b)
	assert(isVector(self) and isVector(b), "NVec expected")
	local c, d = self.x - b.x, self.y - b.y
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

---@param angle number
function nvec:rotateInplace(angle)
	local c, s = cos(angle), sin(angle)
	self.x, self.y = c * self.x - s * self.y, s * self.x + c * self.y
	return self
end

---@param angle number
function nvec:rotate(angle)
	return self:clone():rotateInplace(angle)
end
nvec.rotated = nvec.rotate

---@return NVec
function nvec:perpendicular()
	return __construct(-self.y, self.x)
end

---@param v NVec
---@return NVec
function nvec:projectOn(v)
	assert(isVector(v), "NVec expected")
	-- (self * v) * v / v:len2()
	local s = (self.x * v.x + self.y * v.y) / (v.x * v.x + v.y * v.y)
	return __construct(s * v.x, s * v.y)
end

---@param v NVec
---@return NVec
function nvec:mirrorOn(v)
	assert(isVector(v), "NVec expected")
	-- 2 * self:projectOn(v) - self
	local s = 2 * (self.x * v.x + self.y * v.y) / (v.x * v.x + v.y * v.y)
	return __construct(s * v.x - self.x, s * v.y - self.y)
end

---@param v NVec
---@return NVec
function nvec:cross(v)
	assert(isVector(v), "NVec expected")
	return self.x * v.y - self.y * v.x
end

---@param maxLen number
function nvec:trimInplace(maxLen)
	local s = maxLen * maxLen / (self.x * self.x + self.y * self.y)
	s = (s > 1 and 1) or sqrt(s)
	self.x, self.y = self.x * s, self.y * s
	return self
end

---@param maxLen number
function nvec:trim(maxLen)
	return self:clone():trimInplace(maxLen)
end
nvec.trimmed = nvec.trim

---@param other NVec|nil
---@return number
function nvec:angleTo(other)
	if other then
		return atan2(self.y, self.x) - atan2(other.y, other.x)
	end
	return atan2(self.y, self.x)
end


---@type fun(x: number, y: number): NVec
nvec.new = __construct
nvec.is = isVector
nvec.__index = nvec

if nvec_t then
	-- Make sure NVec is __pairs compatible
	-- https://github.com/MikuAuahDark/NPad93/pull/2
	local function iter(self, v)
		if v == nil then
			return "x", self.x
		elseif v == "x" then
			return "y", self.y
		end
	end

	function nvec:__pairs()
		return iter, self, nil
	end

	-- FFI metatype set for FFI accelerated version
	ffi.metatype(nvec_t, nvec)
end

setmetatable(nvec, {
	__call = function(_, x, y)
		return __construct(x, y)
	end
})

return nvec
