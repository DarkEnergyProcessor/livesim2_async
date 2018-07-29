--[[--------------------------------------------------
	Fusion UI by qfx (qfluxstudios@gmail.com) 
	Copyright (c) 2017-2018 Elmārs Āboliņš
	gitlab.com/project link here 
----------------------------------------------------]]

local path = string.sub(..., 1, string.len(...) - string.len(".elements.frame"))
local gui = require(path .. ".dummy")

---The frame element, this element is used to 'contain' other elements
--As such, it's content is the most complex
--[[
	Content format:
	content = {
		--Inside of this field you add all the elements that will be inside of the frame
		elements = {
			{element = testButtonClass:newElement('Test!'), index = 'button'},
			{element = textClass:newElement('Testing text'), index = 'text'}
		},
		--Inside of the layout field you specify the layout for the elements inside of the frame
		layout = {
			button = {
				position = 'absolute',
				x = 0,
				y = 0,
				w = 100,
				h = 10
			},
			text = {
				
			}
		}
	}

	all layout properties:
	position = absolute (px), relative(%), nil(auto) 
	size = absolute(px), relative(%), calculated(auto)
	w = 100
	h = 100
	left = 100
	right = 100
	top = 100
	bottom = 100
]]
--@module slider
local frame = {}
frame.__index = frame

local misc = gui.elementLib.misc
local state = gui.elementLib.state
local string = gui.elementLib.string

local function get_sizes(prop, elem, fw, fh)
	local x, y, w, h

	prop.position = prop.position or 'calculated '

	if prop.size == 'absolute' and prop.w and prop.h then
		w = prop.w
		h = prop.h
	elseif prop.size == 'relative' and prop.w and prop.h then
		w = (prop.w/100)*fw-elem.style.margins[1]-elem.style.margins[3]
		h = (prop.h/100)*fh-elem.style.margins[2]-elem.style.margins[4]
	else
		w, h = elem:getSize()
	end

	if prop.position == 'absolute' then
		if prop.left then
			x = prop.left+elem.style.margins[1]
		elseif prop.right then
			x = fw - prop.right - elem.style.margins[3] - w
		else
			x = elem.style.margins[1]
		end

		if prop.top then
			y = prop.top+elem.style.margins[2]
		elseif prop.bottom then
			y = fh - prop.bottom - elem.style.margins[4] - h
		else
			y = elem.style.margins[2]
		end
	elseif prop.position == 'relative' then
		if prop.left then
			x = fw*(prop.left/100)+elem.style.margins[1]
		elseif prop.right then
			x = fw - fw*(prop.right/100) - elem.style.margins[3]
		else
			x = elem.style.margins[1]
		end

		if prop.top then
			y = fh*(prop.top/100)+elem.style.margins[2]
		elseif prop.bottom then
			y = fh - fh*(prop.bottom/100) - elem.style.margins[4]
		else
			y = elem.style.margins[2]
		end
	else
		x = elem.style.margins[1]
		y = 'calculated'
	end

	return {x = x, y = y, w = w, h = h}
end
--[[
	Content format:
	content = {
		elements = {
			{element = testButtonClass:newElement('Test!'), index = 'button'},
			{element = textClass:newElement('Testing text'), index = 'text'}
		},
		layout = {
			button = {
				position = 'absolute',
				x = 0,
				y = 0,
				w = 100,
				h = 10
			},
			text = {
				
			}
		}
	}

	all layout properties:
	position = absolute, relative
	size = absolute, relative, calculated
	w = 100
	h = 100
	left = 100
	right = 100
	top = 100
	bottom = 100
]]

function frame.new(content)
	local fr = setmetatable({
		elementContainers = content.elements,
		layout = content.layout or {},
		layoutSettings = content.layoutSettings or {},
		all_nl = content.all_nl or false,
		init = true,
		vOffset = 0,
		type = 'frame',
		mkLayout = true,
		elements = {}
	}, frame)

	for i, eCont in ipairs(fr.elementContainers) do
		eCont.element:addEventListener('changed', fr.elementUpdate, fr, i)
		eCont.element:addEventListener('stylechange', fr.elementUpdate, fr, i)
		eCont.element:addEventListener('styleswitch', fr.elementUpdate, fr, i)
		eCont.element:addEventListener('redrawn', fr.elementRender, fr, i)
		eCont.element:addEventListener('canvasinit', fr.elementRender, fr, i)
		--eCont.element:addEventListener('stylechange', fr.elementUpdate, fr)
		if eCont.index then
			fr.elements[eCont.index] = eCont.element
		end
	end

	return fr
end

function frame:cleanUp()
	gui.input.removeBox(self.box)
	self.box = nil
	
	for i, eCont in ipairs(self.elementContainers) do
		eCont.element:unDraw()
	end
end

function frame:elementUpdate()
	self.mkLayout = true
end

function frame:elementRender()
	self.redraw = true
end

function frame:update(x, y, w, h, content, style, elem)
	if self.redraw then
		elem:emitEvent('changed')
	end

	if self.w ~= w or self.h ~= h then
		self.mkLayout = true
	end

	self.w = w
	self.h = h

	if not self.box then
		self.box = gui.input.addBox(x, y, self.w, self.h, style.z, 1)
	end
	
	if self.mkLayout then
		local elemTree = {}
		for index, eCont in ipairs(self.elementContainers) do
			local elementProps = self.layout[eCont.index] or {}

			eCont.props = get_sizes(elementProps, eCont.element, w-25, h)

			if eCont.props.y == 'calculated' then
				table.insert(elemTree, eCont)
				eCont.props.y = 0
			end
		end

		local curH = style.padding[2]
		local curLH = 0
		local curW =  style.padding[1]
		for i, eCont in ipairs(elemTree) do
			if self.all_nl then
				eCont.props.y = curH + eCont.element.style.margins[2]
				eCont.props.x = curW + eCont.element.style.margins[1]				
				curLH = eCont.props.h + eCont.element.style.margins[4] + eCont.element.style.margins[2]
				curH = curH + curLH
			else
				if curW+eCont.props.w+eCont.element.style.margins[1]+eCont.element.style.margins[3] < w-25 then
					eCont.props.y = curH + eCont.element.style.margins[2]
					eCont.props.x = curW + eCont.element.style.margins[1]
					curW = curW +eCont.props.w+eCont.element.style.margins[1]+eCont.element.style.margins[3]+style.padding[1]
					curLH = eCont.props.h + eCont.element.style.margins[4] + eCont.element.style.margins[2]
				else
					eCont.props.y = curH + curLH + eCont.element.style.margins[2]
					curW = eCont.props.w+eCont.element.style.margins[1]+eCont.element.style.margins[3]+style.padding[1]

					if curW < (w-25)/2 then
						curH = curH + curLH
						curLH = eCont.props.h + eCont.element.style.margins[4] + eCont.element.style.margins[2]
					else
						curH = curH + curLH + eCont.element.style.margins[2] + eCont.props.h + eCont.element.style.margins[4]
						curLH = 0
					end

				end
			end
		end
		
		if curH > self.h then
			if self.slider then
				self.slider.type.max = curH-self.h+30
			else
				self.slider = gui.element.newElement('slider',{min = 0, max = curH-self.h+30, step = 1, current = 0},{})
				
			--[[	self.slider:addEventListener('changed', self.elementUpdate, self)
				self.slider:addEventListener('stylechange', self.elementUpdate, self)
				self.slider:addEventListener('styleswitch', self.elementUpdate, self)]]
				self.slider:addEventListener('redrawn', self.elementRender, self)
				self.slider.doNotSleep = true
			end
		else
			self.slider = nil
			self.vOffset = 0
		end

		elem:emitEvent('changed')
	end

	for i, eCont in ipairs(self.elementContainers) do
		local p = eCont.props
		if not( p.y+self.vOffset-p.h>self.h or p.y-self.vOffset+p.h<0 ) or init then
			eCont.element:draw(p.x+x, p.y+y+self.vOffset, p.w, p.h, nil, false)
			eCont.element:update(0,false)
		end
		init = false
	end

	if self.slider then
		self.slider:draw(self.w-25+x, 0+y+15, 25, self.h-30, nil, false)
		self.slider:update(0, false)
		self.vOffset = -self.slider.type.current
	end

	self.box.w = self.w
	self.box.h = self.h
	self.box.x = x
	self.box.y = y

	local st = state.check(self.box, {
		'pressed', 
		'released', 
		'entered', 
		'exited', 
		'pressEvent', 
		'over',
		'down',
		'dropped',
		'dragged'
	})
	return {
		state = st,

		drawX = x,
		drawY = y,

		static = false,

		w = self.w,
		h = self.h
	}
end

function frame:render(x, y, w, h, content, style)
	style:drawBackground(x, y, w, h)
	love.graphics.setColor(style.foregroundColor)

	--If the layout changed, then re-render all elements
	if self.mkLayout then
		for i, eCont in ipairs(self.elementContainers) do
			local p = eCont.props
			if not( p.y+self.vOffset-p.h>self.h or p.y-self.vOffset+p.h<0 )then
				eCont.element:render(eCont.props.x, eCont.props.y+self.vOffset)
			end
		end
		if self.slider then
			self.slider:render(self.w-25, 0+15)
		end
		self.mkLayout = false
	end

	if self.redraw then
		for i, eCont in ipairs(self.elementContainers) do
			local p = eCont.props
			if not( p.y+self.vOffset-p.h>self.h or p.y-self.vOffset+p.h<0 )then
				eCont.element:render(eCont.props.x, eCont.props.y+self.vOffset)
			end
		end

		if self.slider then
			self.slider:render(self.w-25, 0+15)
		end
		self.redraw = false
	end

	love.graphics.setStencilTest()
end


return frame