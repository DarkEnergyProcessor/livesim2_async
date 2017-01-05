--[[
This package provides functions to carry out Fast Fourier Transformations.

Copyright (C) 2011 by Benjamin von Ardenne

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.

]]

complex = require "complex"

---------------------------------------------------------------
--This is a lua port of the KissFFT Library by Mark Borgerding
--It provides a simple function to carry out a fast fourier transformation (FFT).
--
--module("LuaFFT", package.seeall)

local cos,sin = math.cos,math.sin

debugging = false

function msg(...)
	if debugging == true then
		print(...)
	end
end

---------------------------------------------------------------
-- Returns the next possible size for data input
--
--@param n	Size
--
--@return	Next fast size.
function next_possible_size(n)
  local m = n
  while (1) do
    m = n
    while m%2 == 0 do m = m/2 end
    while m%3 == 0 do m = m/3 end
    while m%5 == 0 do m = m/5 end
	if m <= 1 then break end
    n = n + 1
  end
  return n
end

---------------------------------------------------------------
--Calculates the Fast Fourier Transformation of the given input
--
--@param input		A set of points that will be transformed.
--					At this point, the input has to be a list of complex numbers,
--					according to the format in complex.lua.
--@param inverse	Boolean that controls whether a transformation
--					or inverse transformation will be carried out.
--@return			Returns a list of complex numbers with the same size
--					as the input list. Contains the fourier transformation of the input.
---------------------------------------------------------------
function fft(input, inverse)
	--the size of input defines the number of total points
	local num_points = #input

	assert(#input == next_possible_size(#input), string.format("The size of your input is not correct. For your size=%i, use a table of size=%i with zeros at the end.", #input, next_possible_size(#input)))

	local twiddles = {}
	for i = 0,num_points-1 do
		local phase = -2*math.pi * i / num_points
		if inverse then phase = phase * -1 end
		twiddles[1+i] = complex.new( cos(phase), sin(phase) )
	end
	msg("Twiddles initialized...")
	local factors = calculate_factors(num_points)
	local output = {}
	msg("FFT Initialization completed.\nFactors of size " .. #factors)
	work(input, output, 1, 1, factors,1, twiddles, 1, 1, inverse)
	return output

end

---------------------------------------------------------------
--Calculates the real Fast Fourier Transformation of the given real input
--

---------------------------------------------------------------
function fftr(input, inverse)


end



---------------------------------------------------------------
-- Short helper function that provides an easy way to print a list with values.
---------------------------------------------------------------
function print_list(list)
  for i,v in ipairs(list) do print(i,v) end
end

---------------------------------------------------------------
--The essential work function that performs the FFT
---------------------------------------------------------------
function work(input, output, out_index, f, factors, factors_index, twiddles, fstride, in_stride, inverse)
	local p = factors[factors_index]
	local m = factors[factors_index+1]
	factors_index = factors_index + 2
	msg(p,m)
	local last = out_index + p*m
	local beg = out_index

	if m == 1 then
		repeat
			if type(input[f]) == "number" then output[out_index] = complex.new(input[f],0)
			else output[out_index] = input[f] end
			f = f + fstride*in_stride
			out_index = out_index +1
		until out_index == last
	else
		repeat
			--msg("Out_index", out_index,"f", f)
			work(input, output,out_index,  f, factors, factors_index, twiddles, fstride*p, in_stride, inverse)
			f = f + fstride*in_stride
			out_index = out_index + m
		until out_index == last
	end

	out_index = beg

	if p == 2 then 			butterfly2(output,out_index, fstride, twiddles, m, inverse)
	elseif p == 3 then 		butterfly3(output,out_index, fstride, twiddles, m, inverse)
	elseif p == 4 then 		butterfly4(output,out_index, fstride, twiddles, m, inverse)
	elseif p == 5 then 	butterfly5(output,out_index, fstride, twiddles, m, inverse)
	else 					butterfly_generic(output,out_index, fstride, twiddles, m, p, inverse) end
end


---------------------------------------------------------------
---devides a number into a sequence of factors
--
--@param num_points	Number of points that are used.
--
--@return		Returns a list with the factors
---------------------------------------------------------------
function calculate_factors(num_points)
  local buf = {}
  local p = 4
  floor_sqrt = math.floor( math.sqrt( num_points) )
  local n = num_points
  repeat
    while n%p > 0 do
      if 		p == 4 then p = 2
      elseif 	p == 2 then p = 3
      else 					p = p + 2 end

      if p > floor_sqrt then p = n end
    end
    n = n / p
    table.insert(buf, p)
    table.insert(buf, n)
  until n <= 1
  return buf
end



---------------------------------------------------------------
--Carries out a butterfly 2 run of the input sample.
---------------------------------------------------------------
function butterfly2(input,out_index,fstride, twiddles, m, inverse)
    local i1 = out_index
    local i2 = out_index + m
    local ti = 1
    repeat
      local t = input[i2]* twiddles[ti]
      ti = ti + fstride
      input[i2] = input[i1] - t
      input[i1] = input[i1] + t
      i1 = i1 + 1
      i2 = i2 + 1
      m = m - 1
    until m == 0
end

---------------------------------------------------------------
--Carries out a butterfly 4 run of the input sample.
---------------------------------------------------------------
function butterfly4(input,out_index, fstride, twiddles, m, inverse)
	local ti1, ti2, ti3 = 1,1,1
	local scratch = {}
	local k = m
	local m2 = 2*m
	local m3 = 3*m
	local i = out_index

	repeat
		scratch[0] = input[i+m]*twiddles[ti1]
		scratch[1] = input[i+m2]*twiddles[ti2]
		scratch[2] = input[i+m3]*twiddles[ti3]

		scratch[5] = input[i]-scratch[1]
		input[i] = input[i] + scratch[1]

		scratch[3] = scratch[0] + scratch[2]
		scratch[4] = scratch[0] - scratch[2]

		input[i+m2] = input[i] - scratch[3]
		ti1 = ti1 + fstride
		ti2 = ti2 + fstride*2
		ti3 = ti3 + fstride*3
		input[i] = input[i] + scratch[3]

		if inverse then
			input[i+m][1] = scratch[5][1] - scratch[4][2]
			input[i+m][2] = scratch[5][2] + scratch[4][1]

			input[i+m3][1] = scratch[5][1] + scratch[4][2]
			input[i+m3][2] = scratch[5][2] - scratch[4][1]
		else
			input[i+m][1] = scratch[5][1] + scratch[4][2]
			input[i+m][2] = scratch[5][2] - scratch[4][1]

			input[i+m3][1] = scratch[5][1] - scratch[4][2]
			input[i+m3][2] = scratch[5][2] + scratch[4][1]
		end
		i = i + 1
		k = k - 1
	until k == 0
end

---------------------------------------------------------------
--Carries out a butterfly 3 run of the input sample.
---------------------------------------------------------------
function butterfly3(input,out_index, fstride, twiddles, m, inverse)
	local k = m
	local m2 = m*2
	local tw1, tw2 = 1,1
	local scratch = {}
	local epi3 = twiddles[fstride*m]
	local i = out_index

	repeat
		scratch[1] = input[i+m] * twiddles[tw1]
		scratch[2] = input[i+m2] * twiddles[tw2]
		scratch[3] = scratch[1] + scratch[2]
		scratch[0] = scratch[1] - scratch[2]
		tw1 = tw1 + fstride
		tw2 = tw2 + fstride*2

		input[i+m][1] = input[i][1] - scratch[3][1]*0.5
		input[i+m][2] = input[i][2] - scratch[3][2]*0.5

		scratch[0] = scratch[0]:mulnum(epi3[2] )
		input[i] = input[i] + scratch[3]

		input[i+m2][1] = input[i+m][1] + scratch[0][2]
		input[i+m2][2] = input[i+m][2] - scratch[0][1]

		input[i+m][1] = input[i+m][1] - scratch[0][2]
		input[i+m][2] = input[i+m][2] + scratch[0][1]

		i = i + 1
		k = k-1
	until k == 0

end

---------------------------------------------------------------
--Carries out a butterfly 5 run of the input sample.
---------------------------------------------------------------
function butterfly5(input,out_index, fstride, twiddles, m, inverse)
	local i0,i1,i2,i3,i4 = out_index,out_index+m,out_index+2*m,out_index+3*m,out_index+4*m
	local scratch = {}
	local tw = twiddles
	local ya,yb = tw[1+fstride*m],tw[1+fstride*2*m]
	for u = 0,m-1 do
		scratch[0] = input[i0]

		scratch[1] = input[i1] * tw[1+u*fstride]
		scratch[2] = input[i2] * tw[1+2*u*fstride]
		scratch[3] = input[i3] * tw[1+3*u*fstride]
		scratch[4] = input[i4] * tw[1+4*u*fstride]

		scratch[7] = scratch[1] + scratch[4]
		scratch[8] = scratch[2] + scratch[3]
		scratch[9] = scratch[2] - scratch[3]
		scratch[10] = scratch[1] - scratch[4]

		input[i0][1] = input[i0][1] + scratch[7][1] + scratch[8][1]
		input[i0][2] = input[i0][2] + scratch[7][2] + scratch[8][2]

		scratch[5] = 	complex.new(	scratch[0][1] + scratch[7][1]*ya[1] + scratch[8][1]*yb[1],
										scratch[0][2] + scratch[7][2]*ya[1] + scratch[8][2]*yb[1])

		scratch[6]	=	complex.new(	scratch[10][2]*ya[2] + scratch[9][2]*yb[2],
										-1* scratch[10][1]*ya[2] + scratch[9][1]*yb[2])

		input[i1] = scratch[5] - scratch[6]
		input[i4] = scratch[5] + scratch[6]

		scratch[11] =	complex.new( 	scratch[0][1] + scratch[7][1]*yb[1] + scratch[8][1]*ya[1],
										scratch[0][2] + scratch[7][2]*yb[1] + scratch[8][2]*ya[1])

		scratch[12] =	complex.new( 	-1* scratch[10][2]*yb[2] + scratch[9][2]*ya[2],
										scratch[10][1]*yb[2] - scratch[9][1]*ya[2])

		input[i2] = scratch[11] + scratch[12]
		input[i3] = scratch[11] - scratch[12]

		i0=i0+1
		i1=i1+1
		i2=i2+1
		i3=i3+1
		i4=i4+1

	end

end

---------------------------------------------------------------
--Carries out a generic butterfly run of the input sample.
---------------------------------------------------------------
function butterfly_generic(input,out_index, fstride, twiddles, m, p, inverse )
	local norig = #input

	for u = 0,m-1 do
		local k = u
		for q1 = 0,p-1 do
			scratchbuf[q1] = input[out_index+k]
			k = k + m
		end

		k = u

		for q1=0,p-1 do
			local twidx = 0
			input[out_index+k] = scratchbuf[0]
			for q=1,p-1 do
				twidx = twidx + fstride*k
				if twidx >= Norix then twidx = twidx - Norig end
				local t = scratchbuf[q] * twiddles[1+twidx]
				input[out_index+k] = input[out_index+k] + t
			end
			k = k + m
		end
	end
end
