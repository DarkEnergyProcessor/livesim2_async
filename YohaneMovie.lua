-- Yohane FLSH abstraction layer
-- Class which responsible of the heavy calculation
-- This class is used internally

local Yohane = ({...})[1]
local YohaneMovie = {_internal = {_mt = {}}}

-- math.sign function
local function math_sign(x)
	return x > 0 and 1 or (x < 0 and -1 or 0)
end

-- Affine transformation
local function mat3id()
	return {
		1, 0, 0,
		0, 1, 0,
		0, 0, 1
	}
end

local function mat3af(tm)
	return {
		tm[1], tm[3], tm[5],
		tm[2], tm[4], tm[6],
		0, 0, 1,
		Type = tm.Type
	}
end

local function mat3mul(m1, m2)
	local mc = {
		nil, nil, nil,
		nil, nil, nil,
		nil, nil, nil
	}
	
	for i = 0, 8 do
		local x = math.floor(i / 3) * 3
		mc[i + 1] = m1[x + 1] * m2[(i % 3) + 1] +
					m1[x + 2] * m2[(i % 3) + 4] +
					m1[x + 3] * m2[(i % 3) + 7]
	end
	
	return mc
end

------------------------------
-- Yohane Movie Calculation --
------------------------------
--[[
-- API List

YohaneMovie = YohaneMovie.newMoie(moviedatatable, parentflash)
instruction_data = YohaneMovie:getNextInstruction()
instruction = YohaneMovie:findFrame(frame)
is_stopped = YohaneMovie:stepFrame()
YohaneMovie:draw(x, y)
YohaneMovie:jumpLabel(label_name)

]]--

function YohaneMovie.newMovie(moviedata, parentflash)
	local mvdata = {
		instruction = moviedata.startInstruction + 4,
		currentFrame = 1,
		layers = {},
		highestLayer = 0,
		drawCalls = {},
		parent = parentflash,
		data = moviedata,	-- Beware, recursive table
		__index = YohaneMovie._internal._mt
	}
	
	return (setmetatable({}, mvdata))
end

-- Get next instruction
function YohaneMovie._internal._mt.getNextInstruction(this)
	local inst
	
	this = getmetatable(this)
	inst = this.data.instructionData[this.instruction]
	this.instruction = this.instruction + 1
	
	return inst
end

-- Get new instruction code of frame
function YohaneMovie._internal._mt.findFrame(this, frame)
	local uiFrame = 0
	local instTab
	
	this = getmetatable(this)
	instTab = this.data.instructionData
	
	do
		local i = this.data.startInstruction
		
		while i < this.data.endInstruction do
			local inst = instTab[i]
			
			if inst == 0 then					-- SHOW_FRAME
				uiFrame = uiFrame + 1
				
				if uiFrame == frame then
					return i
				end
				
				i = i + 4
			elseif inst == 1 then				-- PLACE_OBJECT
				i = i + 5
			elseif inst == 2 or inst == 3 then	-- REMOVE_OBJECT or PLAY_SOUND
				i = i + 2
			elseif inst == 4 then				-- PLACE_OBJECT_CLIP
				i = i + 6
			else
				assert(false, "Invalid instruction")
			end
		end
	end
	
	return this.data.startInstruction + 4
end

-- Heavy calculation starts here :v
function YohaneMovie._internal._mt:stepFrame()
	local this = getmetatable(self)
	
	if this.frozen then return end
	
	-- Clear draw calls here
	for i = #this.drawCalls, 1, -1 do
		this.drawCalls[i] = nil
	end
	
	repeat
		local instr = self:getNextInstruction()
		
		if instr == 0 then
			-- SHOW_FRAME
			local label = self:getNextInstruction()
			local frame_type = self:getNextInstruction()
			local frame_target = self:getNextInstruction() + 1
			
			if frame_type == 0 then
				-- STOP_INSTRUCTION
				this.frozen = true
			elseif frame_type == 1 then
				-- GOTO_AND_PLAY
				this.instruction = self:findFrame(frame_target)
			elseif frame_type == 2 then
				-- GOTO_AND_STOP
				this.instruction = self:findFrame(frame_target)
				this.frozen = true
			elseif this.instruction >= this.data.endInstruction then
				-- Loop it
				this.instruction = this.data.startInstruction + 4
			end
			
			local updatedMovies = {}
			for n = 1, this.highestLayer do
				local v = this.layers[n]
				
				if v then
					local movieObj = assert(this.parent.movieData[v.movieID], "Unknown movie was specificed")
					
					if movieObj.type == "flash" then
						if not(updatedMovies[movieObj]) then
							-- Frame step it if it's not already
							movieObj.data:stepFrame()
							updatedMovies[movieObj] = true
						end
						
						-- Then get it's draw calls
						local movieObjMovie = getmetatable(movieObj.data)
						for a = 1, #movieObjMovie.drawCalls do
							local b = movieObjMovie.drawCalls[a]
							local dc = {image = b.image}
							
							-- Matrix multiply
							dc.matrix = mat3mul(v.matrix, b.matrix)
							
							-- Color transformation
							dc.r = v.color.r * b.r
							dc.g = v.color.g * b.g
							dc.b = v.color.b * b.b
							dc.a = v.color.a * b.a
							
							this.drawCalls[#this.drawCalls + 1] = dc
						end
					elseif movieObj.type == "image" then
						-- Simple image. It has offsets
						local dc = {image = movieObj.imageHandle}
						
						dc.matrix = mat3mul(
							v.matrix,
							{1, 0, movieObj.offsetX, 0, 1, movieObj.offsetY, 0, 0, 1}
						)
						
						dc.r = v.color.r
						dc.g = v.color.g
						dc.b = v.color.b
						dc.a = v.color.a
						
						this.drawCalls[#this.drawCalls + 1] = dc
					end
				end
			end
		elseif instr == 1 or instr == 4 then
			-- PLACE_OBJECT or PLACE_OBJECT_CLIP
			local movieID = self:getNextInstruction()
			local matrixIdx = self:getNextInstruction()
			local matrixColIdx = self:getNextInstruction()
			local layer = self:getNextInstruction()
			
			if instr == 4 then
				self:getNextInstruction()	-- Clip layer (unused)
			end
			
			-- Get layer matrix and such
			if not(this.layers[layer]) then
				this.layers[layer] = {
					matrix = mat3id(),
					color = {r = 1, g = 1, b = 1, a = 1}
				}
			end
			
			local layerdata = this.layers[layer]
			
			if movieID == 65535 then
				assert(layerdata.movieID, "MovieID 65535 used without initialized")
			else
				layerdata.movieID = movieID
			end
			
			this.highestLayer = math.max(this.highestLayer, layer)
			
			if matrixIdx ~= 65535 then
				-- Set matrix data
				local tm = assert(this.parent.matrixTransf[matrixIdx], "Invalid matrix")
				
				if tm.Type == 0 then
					-- Identity
					layerdata.matrix = mat3id()
				elseif tm.Type == 4 then
					-- Invalid
					assert(false, "MATRIX_COL specificed for Matrix Index")
				else
					-- MATRIX_TS, MATRIX_TG
					layerdata.matrix = mat3af(tm)
				end
			end
			
			if matrixColIdx ~= 65535 then
				-- MATRIX_COL
				local tc = assert(this.parent.matrixTransf[matrixColIdx], "Invalid matrix")
				
				if tc.Type == 0 then
					layerdata.color.r = 1
					layerdata.color.g = 1
					layerdata.color.b = 1
					layerdata.color.a = 1
				elseif tc.Type == 4 then
					layerdata.color.r = tc[1]
					layerdata.color.g = tc[2]
					layerdata.color.b = tc[3]
					layerdata.color.a = tc[4]
				else
					assert(false, "Matrix specificed for color is not MATRIX_COL type")
				end
			end
		elseif instr == 2 then
			-- REMOVE_OBJECT
			local layer = self:getNextInstruction()
			this.layers[layer] = nil
			
			if layer == this.highestLayer then
				local newhighest = 0
				
				for i = layer, 1, -1 do
					if this.layers[i] then
						newhighest = i
						break
					end
				end
				
				this.highestLayer = newhighest
			end
		elseif instr == 3 then
			-- PLAY_SOUND
			local soundID = self:getNextInstruction() + 1
			local sound = assert(this.parent.audios[soundID], "Invalid sound ID")
			
			if sound.handle then
				Yohane.Platform.PlayAudio(sound.handle)
			end
		else
			assert(false, "Invalid instruction")
		end
	until instr == 0
	
	return this.frozen
end

function YohaneMovie._internal._mt.draw(this, x, y)
	local newdc = {}
	this = getmetatable(this)
	
	for i = 1, #this.drawCalls do
		local a = this.drawCalls[i]
		local tm = a.matrix
		local z = {}
		
		z.image = a.image
		
		z.x = tm[3] + x
		z.y = tm[6] + y
		z.scaleX = math_sign(tm[1]) * math.sqrt(tm[1] * tm[1] + tm[2] * tm[2])
		z.scaleY = math_sign(tm[5]) * math.sqrt(tm[4] * tm[4] + tm[5] * tm[5])
		z.rotation = math.atan2(tm[2] / z.scaleX, tm[5] / z.scaleY)
		
		z.r = a.r * 255
		z.g = a.g * 255
		z.b = a.b * 255
		z.a = a.a * this.parent.opacity
		
		newdc[i] = z
	end
	
	Yohane.Platform.Draw(newdc)
end

function YohaneMovie._internal._mt.jumpLabel(this, label)
	local instTab
	local strTab
	
	this = getmetatable(this)
	instTab = this.data.instructionData
	strTab = this.parent.strings
	
	this.frozen = false
	
	do
		local i = this.data.startInstruction
		
		while i < this.data.endInstruction do
			local inst = instTab[i]
			
			if inst == 0 then					-- SHOW_FRAME
				local lbl = instTab[i + 1]
				
				if lbl ~= 65535 and strTab[lbl] == label then
					return i
				end
				
				i = i + 4
			elseif inst == 1 then				-- PLACE_OBJECT
				i = i + 5
			elseif inst == 2 or inst == 3 then	-- REMOVE_OBJECT or PLAY_SOUND
				i = i + 2
			elseif inst == 4 then				-- PLACE_OBJECT_CLIP
				i = i + 6
			else
				assert(false, "Invalid instruction")
			end
		end
	end
	
	return this.data.startInstruction + 4
end

return YohaneMovie
