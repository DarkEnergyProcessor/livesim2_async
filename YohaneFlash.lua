-- Yohane FLSH abstraction layer
-- Class which contain Flash data
-- Meant to be loaded via loadstring("YohaneFlash.lua")(YohaneTable)

local Yohane = ({...})[1]
local YohaneFlash = {_internal = {_mt = {}}}

-------------------------------------------
-- Basic conversion, copied from Shelsha --
-------------------------------------------
local function string2dwordu(a)
	local str = assert(a:read(4))
	
	return str:byte() * 16777216 + str:sub(2, 2):byte() * 65536 + str:sub(3, 3):byte() * 256 + str:sub(4, 4):byte()
end

local function string2wordu(a)
	local str = assert(a:read(2))
	
	return str:byte() * 256 + str:sub(2, 2):byte()
end


local function readstring(stream)
	local len = string2wordu(stream)
	--[[
	local lensub = (len % 2) == 0 and -3 or -2
	
	return stream:read(len):sub(1, lensub)
	]]
	return ({stream:read(len):gsub("%z", "")})[1]
end

-------------------------
-- Yohane Flash Reader --
-------------------------
--[[
-- API Function List
-- Assume "YohaneFlash" is the Yohane object containing all flash data

YohaneFlash = Yohane.newFlashFromStream(stream, movie_name|nil)
YohaneFlash = Yohane.newFlashFromString(string, movie_name|nil)
YohaneFlash = Yohane.newFlashFromFilename(filename, movie_name|nil)
YohaneFlash = YohaneFlash:clone()
YohaneFlash:update(deltaT in milliseconds)
YohaneFlash:draw(x, y)
YohaneFlash:setMovie(movie_name)
YohaneFlash:unFreeze()
YohaneFlash:jumpToLabel(label_name)

previous_fps = YohaneFlash:setFPS(fps|nil)
PlatformImage = YohaneFlash:getImage(image_name)
movie_frozen = YohaneFlash:isFrozen()
]]--

-- Creates Yohane Flash Abstraction from specificed stream
function YohaneFlash._internal.parseStream(stream)
	local flsh = {
		timeModulate = 0,
		strings = {},
		audios = {},
		matrixTransf = {},
		movieData = {},
		instrData = {},
		__index = YohaneFlash._internal._mt
	}
	
	assert(stream:read(4) == "FLSH", "Not a Playground Flash file")
	stream:read(4)	-- Skip size
	
	flsh.name = readstring(stream)
	flsh.msPerFrame = string2wordu(stream)
	
	local stringsCount = string2wordu(stream)
	stream:read(2)	-- Skip total string size
	
	if stringsCount == 65535 then
		-- Sound extension
		local soundCount = string2wordu(stream)
		
		if soundCount > 0 then
			for i = 1, soundCount do
				flsh.audios[i] = {nameIdx = string2wordu(stream)}
			end
		end
		
		local indexTotal = string2dwordu(stream)
		local shapeCount = string2wordu(stream)
		
		for i = 1, shapeCount do
			-- Ignore shape atm
			local shapeStyle
			
			stream:read(2)
			shapeStyle = string2wordu(stream)
			
			for j = 1, shapeStyle do
				local idx = string2dwordu(stream)
				local endidx = string2wordu(stream) - idx
				
				-- Ignore data
				stream:read(endidx * 2 + 10)
				
				local styleType = stream:read(1):byte()
				
				if styleType == 1 then
					stream:read(4)
				elseif styleType == 2 or styleType == 3 then
					stream:read(256)
				end
			end
		end
		
		stringsCount = string2wordu(stream)
	end
	
	-- Read strings data
	for i = 1, stringsCount do
		flsh.strings[i - 1] = readstring(stream)
	end
	
	local matrixCount = string2dwordu(stream)
	local floatsCount = string2dwordu(stream)
	local floats = {}
	
	-- Read float constants
	for i = 1, floatsCount do
		local x = string2dwordu(stream) / 65536
		
		floats[i - 1] = math.floor(x / 32768) * (-65536) + x	-- To signed
	end
	
	-- Read matrix data
	for i = 1, matrixCount do
		local matrixData = nil
		local mtrxType = stream:read(1):byte()
		local mtrxIdx = string2dwordu(stream)
		
		if mtrxType == 0 then
			-- MATRIX_ID, Identity
			matrixData = {Type = 0, 1, 0, 0, 1, 0, 0}
		elseif mtrxType == 1 then
			-- MATRIX_T, Translate
			matrixData = {Type = 1, 1, 0, 0, 1, floats[mtrxIdx], floats[mtrxIdx + 1]}
		elseif mtrxType == 2 then
			-- MATRIX_TS, Translation and Scale
			matrixData = {Type = 2, floats[mtrxIdx], 0, 0, floats[mtrxIdx + 1], floats[mtrxIdx + 2], floats[mtrxIdx + 3]}
		elseif mtrxType == 3 then
			-- MATRIX_TG, Translation, Skew, and Scale
			matrixData = {Type = 3,
				floats[mtrxIdx]    , floats[mtrxIdx + 2], floats[mtrxIdx + 3],
				floats[mtrxIdx + 1], floats[mtrxIdx + 4], floats[mtrxIdx + 5]
			}
		elseif mtrxType == 4 then
			-- MATRIX_COL, RGBA color component, from 0.0 to 1.0
			matrixData = {Type = 4,
				floats[mtrxIdx],
				floats[mtrxIdx + 1],
				floats[mtrxIdx + 2],
				floats[mtrxIdx + 3],
			}
		end
		
		flsh.matrixTransf[i - 1] = matrixData
	end
	
	-- Read instructions
	local instrCount = string2dwordu(stream)
	for i = 1, instrCount do
		flsh.instrData[i - 1] = string2dwordu(stream)
	end
	
	-- Read movie data
	local movieCount = string2wordu(stream)
	for i = 1, movieCount do
		local moviedata = {string2dwordu(stream), string2dwordu(stream), string2dwordu(stream), string2dwordu(stream)}
		local movie = {}
		
		if moviedata[2] < 0x8000 then
			-- Flash movie
			movie.type = "flash"
			movie.name = flsh.strings[moviedata[1]]
			movie.startInstruction = moviedata[3]
			movie.endInstruction = moviedata[4]
			movie.instructionData = flsh.instrData
			movie.frameCount = moviedata[2]
			movie.data = Yohane.Movie.newMovie(movie, flsh)
		elseif moviedata[2] == 0xFFFF then
			-- Image
			movie.type = "image"
			movie.name = flsh.strings[moviedata[1]]
			movie.offsetX = math.floor(moviedata[3] / 2147483648) * (-4294967296) + moviedata[3]	-- To signed
			movie.offsetY = math.floor(moviedata[4] / 2147483648) * (-4294967296) + moviedata[4]	-- To signed
			movie.imageHandle = Yohane.Platform.ResolveImage(movie.name:sub(2, -6))
		elseif moviedata[2] == 0x8FFF then
			-- Shape
			movie.type = "shape"
			-- No support for shape atm
		else
			movie.type = "unknown"
		end
		
		flsh.movieData[i - 1] = movie
	end
	
	-- Resolve audios
	for i = 1, #flsh.audios do
		local h = flsh.audios[i]
		
		if flsh.strings[h.nameIdx] then
			h.handle = Yohane.Platform.ResolveAudio(flsh.strings[h.nameIdx]:sub(9))
		end
	end
	
	return setmetatable({}, flsh)
end

-- Clones current Yohane instance to new one.
function YohaneFlash._internal._mt.clone(this)
	this = getmetatable(this)
	
	local flsh = {
		timeModulate = 0,
		msPerFrame = this.msPerFrame,
		strings = Yohane.CopyTable(this.strings),
		audios = {},
		matrixTransf = {},
		movieData = {},
		instrData = Yohane.CopyTable(this.instrData),
		__index = YohaneFlash._internal._mt
	}
	
	-- Copy matrix transform data
	for i = 0, #this.matrixTransf do	-- 0-index based. Index 0 is not counted on len operation
		flsh.matrixTransf[i] = Yohane.CopyTable(this.matrixTransf[i])
	end
	
	-- Copy movie data
	for i = 0, #this.movieData do
		
		if this.movieData[i].type == "flash" then
			flsh.movieData[i] = Yohane.CopyTable(this.movieData[i], "data")
			flsh.movieData[i].data = Yohane.Movie.newMovie(flsh.movieData[i], flsh)
			
			if this.movieData[i].data == this.currentMovie then
				flsh.currentMovie = flsh.movieData[i].data
			end
		elseif this.movieData[i].type == "image" then
			flsh.movieData[i] = Yohane.CopyTable(this.movieData[i], "imageHandle")
			flsh.movieData[i].imageHandle = Yohane.Platform.CloneImage(this.movieData[i].imageHandle)
		else
			flsh.movieData[i] = Yohane.CopyTable(this.movieData[i])
		end
	end
	
	-- Copy audio
	for i = 1, #this.audios do
		flsh.audios[i - 1] = {
			nameIdx = this.audios[i - 1].nameIdx,
			handle = Yohane.Platform.CloneAudio(this.audios[i - 1].handle)
		}
	end
	
	return setmetatable({}, flsh)
end

-- Get image object from specificed name
-- The image objecr returned is platform-dependant, example
-- for LOVE2D platform, it will be LOVE2D Image object.
function YohaneFlash._internal._mt.getImage(this, name)
	this = getmetatable(this)
	
	for i = 0, #this.movieData do
		local x = this.movieData[i]
		
		if x.type == "image" and x.name and x.name:sub(2) == name then
			return x.imageHandle
		end
	end
	
	return nil
end

-- Update flash
function YohaneFlash._internal._mt.update(this, deltaT)
	this = getmetatable(this)
	assert(this.currentMovie, "No movie render is set")
	
	if this.movieFrozen then return end
	
	this.timeModulate = this.timeModulate + deltaT
	
	if this.timeModulate >= this.msPerFrame then
		this.timeModulate = this.timeModulate - this.msPerFrame
		this.movieFrozen = this.currentMovie:stepFrame()
	end
end

-- Draw
function YohaneFlash._internal._mt.draw(this, x, y)
	this = getmetatable(this)
	assert(this.currentMovie, "No movie render is set")
	
	this.currentMovie:draw(x or 0, y or 0)
end

function YohaneFlash._internal._mt.setMovie(this, movie_name)
	this = getmetatable(this)
	
	for i = 0, #this.movieData do
		local x = this.movieData[i]
		
		if x.type == "flash" and x.name and x.name:sub(2) == movie_name then
			this.currentMovie = x.data
			
			return true
		end
	end
	
	return false
end

function YohaneFlash._internal._mt:jumpToLabel(label_name)
	local this = getmetatable(self)
	assert(this.currentMovie, "No movie render is set")
	
	if this.movieFrozen then
		this.movieFrozen = false
	end
	
	getmetatable(this.currentMovie).instruction = this.currentMovie:jumpLabel(label_name)
end

function YohaneFlash._internal._mt.isFrozen(this)
	this = getmetatable(this)
	assert(this.currentMovie, "No movie render is set")
	
	return this.movieFrozen
end

return YohaneFlash
