--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

---The style module is Fusion UI's equivalent of HTML's CSS, every event has a style, even if you don't set one
--These are the default values for a style, you should modify every field that you don't want following the default one
--[[style.defaultStyle = {
	--Global/Common settings
	--Getting a default font on load
	font = love.graphics.getFont(),

	--Color scheme
	foregroundColor = { --Bone white
		200,
		200,
		200,
		255
	},
	accentColor = { --Muted red
		30,
		30,
		30
	},
	outlineColor = { --Muted red
		150,
		20,
		20,
		255
	},
	backgroundColor = { --Charcoal
		30,
		30,
		30,
		255
	},
	backgroundImage = love.graphics.newImage('/gui/empty.png'), --Love Image type
	backgroundTiling = false,
	backgroundImageColor = {255,255,255,255},
	backgroundSize = 'center', --center, fit, stretch 
	accent = {
		direction = 'down', --up down left right
		size = 0,
		style = 'uniform' --gradient uniform
	},
	margins = {
		5,
		0,
		0,
		0
	},
	padding = {
		0,
		0,
		0,
		0
	},
	outline = 0,
	cornerRadius = 0,
	z = 1
}
]]
--@module style

--Merges 2 tables with preferrance for the second one
local function copyTableRecursive(tB)
	local finalTable = {}

	for index, element in pairs(tB) do
		--Checks if it needs to go one level deeper, making sure that 
		if type(element) == 'table' then
			--Makes sure there is a sub table to copy
			finalTable[index] = copyTableRecursive(element)
		--Checks if the 'old table' has the same type 
		else
			finalTable[index] = element
		end
	end

	return finalTable
end

local function mergeTableRecursive(tB,tO,elem)
	local oldTable, baseTable, finalTable
	oldTable = tO
	baseTable = tB
	finalTable = {}

	for index, element in pairs(baseTable) do
		--Checks if it needs to go one level deeper
		if type(element) == 'table' then
			--Makes sure there is a sub table to copy
			if oldTable[index] and type(oldTable[index]) == 'table' then
				finalTable[index] = mergeTableRecursive(element, oldTable[index])
			--Else we just copy the base table
			else
				finalTable[index] = copyTableRecursive(element)
			end
		--Checks if the 'old table' has the same type 
		elseif oldTable and oldTable[index] and type(oldTable[index]) == type(baseTable[index]) then
			finalTable[index] = oldTable[index]
		else
			finalTable[index] = element
		end
	end

	return finalTable
end 

--Determines if it is a 'registered' style
local function isStyle(tbl)
	if type(tbl) == 'table' then
		if getmetatable(tbl) == style then
			return true
		end
	end

	return true
end

local path = string.sub(..., 1, string.len(...) - string.len(".core.style"))
local gui = require(path .. ".dummy")

local style = {
	defaultImage = gui.platform.newImage(love.image.newImageData(1,1))
}
style.__index = style

style.defaultStyle = {
	--Global/Common settings
	--Getting a default font on load
	font = gui.platform.getFont(),

	--Color scheme
	foregroundColor = { --Bone white
		200,
		200,
		200,
		255
	},
	accentColor = { --Muted red
		30,
		30,
		30
	},
	outlineColor = { --Muted red
		150,
		20,
		20,
		255
	},
	backgroundColor = { --Charcoal
		30,
		30,
		30,
		255
	},
	backgroundImage = style.defaultImage, --Love Image type
	backgroundTiling = false,
	backgroundImageColor = {255,255,255,255},
	align = 'center',
	backgroundSize = 'center', --center, fit, stretch 
	accent = {
		direction = 'down', --up down left right
		size = 0,
		style = 'uniform' --gradient uniform
	},
	margins = {
		5,
		5,
		0,
		0
	},
	padding = {
		0,
		0,
		0,
		0
	},
	outline = 0,
	cornerRadius = 0,
	z = 1
	--Elements will add custom entries upon load (or should)
}

--Function to set the default style as the current one, after elements have added their own 
function style.finalize()
	style.currentStyle = style.defaultStyle
	style.currentDefaultStyle = style.defaultStyle
end

---Creates and returns a new style from the supplied table
--@param tbl A table formatted as shown above
function style.newStyle(tbl)
	--Merging the input table with the default table to get the valid entries
	local sTable = mergeTableRecursive(style.defaultStyle, tbl)

	--Setting the metatable to style, indicating that it is a valid userdata - a style
	return setmetatable(sTable, style)
end

---Deep copies a style
function style.copyStyle(sty)
	local locT = copyTableRecursive(sty)
	return setmetatable(locT, style)
end

function style.mergeStyle(s1,s2)
	--Merging the input table with the default table to get the valid entries
	local sTable = mergeTableRecursive(s1, s2)

	--Setting the metatable to style, indicating that it is a valid userdata - a style
	return setmetatable(sTable, style)
end

function style.setStyle(tbl)
	if isStyle(tbl) then
		style.currentStyle = tbl

		return true
	else
		return false
	end
end

---Use this to set a new default style
function style.setDefaultStyle(style)
	if isStyle(tbl) then
		style.currentDefaultStyle = tbl

		return true
	else
		return false
	end
end

--Shallow copy the current table so that it's no longer linked to the base
function style.getCurrentStyle()
	return setmetatable(copyTableRecursive(style.currentStyle), style)
end

function style.returnDefault()
	style.currentStyle = style.currentDefaultStyle
end

--Methods
function style:drawBackground(x, y, w, h)
	--Local stencil function
	local stencilFunction = function()
		gui.platform.rectangle('fill',x, y, w, h, self.cornerRadius, self.cornerRadius, 10)
	end

	--Setting the stencil state
	gui.platform.stencil(stencilFunction, "replace", 1)
	gui.platform.setStencilTest('greater', 0)

	--Drawing the background rectangle
	gui.platform.setColor(self.backgroundColor)
	gui.platform.rectangle('fill', x, y, w, h, self.cornerRadius, self.cornerRadius, 10)

		--Drawing the background image
		if self.backgroundImage~=style.defaultImage then
			gui.platform.setColor(self.backgroundImageColor)
			if not self.backgroundSize or self.backgroundSize == 'center' then
				local overShootX, overShootY, imgW, imgH
	
				imgW, imgH = self.backgroundImage:getDimensions()
	
				overShootX = (imgW-w)/2
				overShootY = (imgH-h)/2
	
				gui.platform.draw(self.backgroundImage, x-overShootX, y-overShootY)
			elseif self.backgroundSize == 'fit' then
				local imgRatio, vOdr, hRatio, imgW, imgH
				
				imgW, imgH = self.backgroundImage:getDimensions()
	
				imgRatio=imgW/imgH
	
				hRatio = w/imgW
				vOdr = imgH*hRatio-h
	
				gui.platform.draw(self.backgroundImage, x, y-((vOdr/2)), 0, hRatio, hRatio)
			elseif self.backgroundSize == 'cover' then
				local imgRatio, vOdr, hRatio, imgW, imgH

				imgW, imgH = self.backgroundImage:getDimensions()
				
				hRatio = h/imgH
				vOdr = imgH*hRatio-h
	
				gui.platform.draw(self.backgroundImage, x, y-((vOdr/2)), 0, hRatio, hRatio)
			end
		end

	if self.accent.style == 'gradient' then
		--Getting the accent steps for each color
		local accentStep

		accentStep = {
			math.floor((self.accentColor[1]-self.backgroundColor[1])/self.accent.size),
			math.floor((self.accentColor[2]-self.backgroundColor[2])/self.accent.size),
			math.floor((self.accentColor[3]-self.backgroundColor[3])/self.accent.size)
		}

		if self.accent.direction=='down' then
			for i = 1, self.accent.size do
				gui.platform.setColor(
					self.backgroundColor[1]+accentStep[1]*i,
					self.backgroundColor[2]+accentStep[2]*i,
					self.backgroundColor[3]+accentStep[3]*i
				)

				gui.platform.line(x, y+h-self.accent.size+i, x+w, y+h-self.accent.size+i)
			end
		end
	elseif self.accent.style == 'uniform' then
		gui.platform.setColor(self.accentColor)

		if self.accent.direction=='down' then
			gui.platform.rectangle('fill', x, y+h-self.accent.size, w, self.accent.size)
		end
	end

	if self.outline > 0 then
		gui.platform.setColor(self.outlineColor)
		gui.platform.rectangle('line', x, y, w, h, self.cornerRadius, self.cornerRadius, 10)
	end

--[[	if self.outline[1]>0 then
		love.graphics.setLineWidth(self.outline[1])
		love.graphics.setColor(self.outlineColor)
		love.graphics.]]
end



style.defaultStyle = style.newStyle(style.defaultStyle)

return style
