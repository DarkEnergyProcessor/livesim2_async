-- AquaShine User Interface library
-- Part of Live Simulator: 2

local AquaShine = select(1, ...)
local UI = {_mousehook = {}}

local function copy_table(...)
	local a = {...}
	local t2 = {}
	
	for i = 1, #a do
		for n, v in pairs(a[i]) do
			t2[n] = v
		end
	end
	
	return t2
end

------------------
-- World Object --
------------------
local w = {_type = "AquaShineWorldUI"}
local w_mt = {__index = w}
--[[
AquaShineWorldUI w = {
	-- Properties
	table List;
	
	-- Methods
	AquaShineWorldUI Insert(AquaShineUIObject UI);
	void Update(number deltaT);
	void Draw();
	bool MousePressed(number x, number y, number button, any touch_id);
	bool MouseMoved(number x, number y);
	bool MouseReleased(number x, number y, number button, any touch_id);
};
]]

function w.Insert(world, ui)
	local last_ui = world.List[#world.List]
	world.List[#world.List + 1] = ui
	
	if last_ui then
		last_ui._next = ui
	end
	ui._previous = last_ui
	ui:_recalculate_ui()
	
	return world
end

function w.Draw(world)
	love.graphics.push("all")
	
	for i = 1, #world.List do
		local ui = world.List[i]
		
		love.graphics.setColor(ui._color)
		ui:_draw()
	end
	
	love.graphics.pop()
end

function UI.NewWorld()
	local this = setmetatable({}, w_mt)
	this.List = {}
	
	return this
end

------------------------------
-- AquaShine UI Base Object --
------------------------------
local base_object = {_type = "AquaShineUIObject"}
local base_object_mt = {__index = base_object}
--[[
Note: variable starting with "_" means "Used internally"
AquaShineUIObject base_object = {
	-- Properties
	number _real_x;
	number _real_y;
	number _x;
	number _y;
	number|string _arg_x;
	number|string _arg_y;
	number _real_width;
	number _real_height;
	table _previous;
	table _next;
	table _relative;
	table _gravity;
	table _color;
	
	-- Internal Methods
	void _recalculate_ui();
	void _draw();
	
	-- Public Methods
	void SetDimension(x, y[, w,[ h] ])
	string Type();
};
]]

-- Internal function to recalculate UI position
function base_object._recalculate_ui(ui)
	ui._real_x = ui._x
	ui._real_y = ui._y
	
	-- Relative from previous UI
	if ui._relative then
		assert(ui._previous, "No previous UI to use relative coordinates")
		
		ui._real_x = ui._real_x + ui._previous._real_x
		ui._real_y = ui._real_y + ui._previous._real_y
		
		-- X parent gravity
		if ui._relative.center_h then
			ui._real_x = ui._real_x + ui._previous._real_width * 0.5
		elseif ui._relative.right then
			ui._real_x = ui._real_x + ui._previous._real_width
		end
		
		-- Y parent gravity
		if ui._relative.center_v then
			ui._real_y = ui._real_y + ui._previous._real_height * 0.5
		elseif ui._relative.bottom then
			ui._real_y = ui._real_y + ui._previous._real_height
		end
	end
	
	-- Current UI gravity
	if ui._gravity then
		-- X gravity
		if ui._gravity.center_h then
			ui._real_x = ui._real_x - ui._real_width * 0.5
		elseif ui._gravity.right then
			ui._real_x = ui._real_x - ui._real_width
		end
		
		-- Y gravity
		if ui._gravity.center_v then
			ui._real_y = ui._real_y - ui._real_height * 0.5
		elseif ui._gravity.bottom then
			ui._real_y = ui._real_y - ui._real_height
		end
	end
	
	if ui._next then
		-- Tail call
		return ui._next:_recalculate_ui()
	end
end

function base_object._draw()
end

function base_object._set_dimension(this, x, y, w, h)
	local gravity_data = {}
	local relative_data = {}
	local has_gravity = false
	local has_relative = false
	
	this._arg_x = x
	this._arg_y = y
	
	if type(x) == "number" then
		this._x = x
		this._real_x = x
	elseif type(x) == "string" then
		local rel, desired_x, grav = x:match("([L|R|C]?)(%-?%d+)([l|r|c]?)")
		assert(desired_x, "Invalid position format")
		
		if grav and #grav > 0 and grav ~= "l" then
			has_gravity = true
			gravity_data.center_h = grav == "c"
			gravity_data.right = grav == "r"
		end
		
		if rel and #rel > 0 and rel ~= "L" then
			has_relative = true
			relative_data.center_h = rel == "C"
			relative_data.right = rel == "R"
		end
		
		this._x = tonumber(desired_x)
	end
	
	if type(y) == "number" then
		this._y = y
		this._real_y = y
	elseif type(y) == "string" then
		local rel, desired_y, grav = y:match("([T|B|C]?)(%-?%d+)([t|b|c]?)")
		assert(desired_y, "Invalid position format")
		
		if grav and #grav > 0 and grav ~= "t" then
			has_gravity = true
			gravity_data.center_v = grav == "c"
			gravity_data.bottom = grav == "b"
		end
		
		if rel and #rel > 0 and rel ~= "T" then
			has_relative = true
			relative_data.center_v = rel == "C"
			relative_data.bottom = rel == "B"
		end
		
		this._y = tonumber(desired_y)
	end
	
	if has_gravity then
		this._gravity = gravity_data
	end
	
	if has_relative then
		this._relative = relative_data
	end
	
	this._real_width = w
	this._real_height = h
end

function base_object.SetDimension(this, x, y, w, h)
	this:_set_dimension(x, y, w, h)
	this:_recalculate_ui()
end

function base_object.Type(this)
	return this._type
end

-- Constructor
local function _create_new_ui(x, y, w, h, mt)
	local this = setmetatable({}, mt or base_object_mt)
	this._arg_x = x
	this._arg_y = y
	this._color = {255, 255, 255, 255}
	
	this:_set_dimension(x, y, w, h)
	return this
end

function UI.NewObject(x, y, w, h)
	return _create_new_ui(x, y, w, h)
end

-------------------------------
-- AquaShine UI Image Object --
-------------------------------
local image_ui = copy_table(base_object, {_type = "AquaShineUIImage"})
local image_ui_mt = {__index = image_ui}
--[[
AquaShineUIImage image_ui: AquaShineUIObject = {
	-- Properties
	love::Image _image
	
	-- Methods
	love::Image SetImage(love::Image new_image);
}
]]

function image_ui.SetImage(this, image)
	local old_image = this._image
	
	if image then
		this._image = image
	end
	
	return old_image
end

function image_ui._draw(this)
	love.graphics.draw(this._image, this._real_x, this._real_y)
end

function UI.NewImage(image, x, y)
	local iw, ih = image:getDimensions()
	local this = _create_new_ui(x, y, iw, ih, image_ui_mt)
	
	this._image = image
	
	return this
end

------------------------------
-- AquaShine UI Text Object --
------------------------------
local text_ui = copy_table(base_object, {_type = "AquaShineUIText"})
local text_ui_mt = {__index = text_ui}
--[[
AquaShineUIText image_ui: AquaShineUIObject = {
	-- Properties
	string _text
	string _font
	number _font_height
	number _outline
	
	-- Methods
	string SetText(string text)
	love::Font SetFont(love::Font font)
	void SetOutline(number pixels)
}
]]

function text_ui.SetText(this, text)
	local old_text = this._text
	
	if text then
		local w, h = text:gsub("[\r\n|\r|\n]", "%1")
		w = this._font:getWidth(text)
		h = (h + 1) * this._font_height
		
		this._text = text
		this:SetDimension(this._arg_x, this._arg_y, w, h)
	end
	
	return old_text
end

function text_ui._draw(this)
	local r, g, b, a = love.graphics.getColor()
	love.graphics.setFont(this._font)
	
	if this._outline then
		love.graphics.setColor(0, 0, 0, a)
		love.graphics.print(this._text, this._real_x + this._outline, this._real_y + this._outline)
		love.graphics.print(this._text, this._real_x - this._outline, this._real_y - this._outline)
		love.graphics.setColor(r, g, b, a)
	end
	
	love.graphics.print(this._text, this._real_x, this._real_y)
end

function UI.NewText(font, text, x, y, outline)
	local font_height = font:getHeight()
	
	local w, h = text:gsub("[\r\n|\r|\n]", "%1")
	w = font:getWidth(text)
	h = (h + 1) * font_height
	
	local this = _create_new_ui(x, y, w, h, text_ui_mt)
	this._text = text
	this._font = font
	this._font_height = font_height
	this._outline = outline
	return this
end

-------------------------
-- End of AquaShine UI --
-------------------------
AquaShine.UI = UI
