-- Note image handling
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = love
local bit = require("bit")
local DEPLS, AquaShine = ...
local NoteImageLoader = {}

local function make_cache_table(link)
	return setmetatable({}, {__index = function(a, var)
		a[var] = AquaShine.LoadImage(link[var])
		return a[var]
	end})
end

local newstyle_opacitymul = love.graphics.newShader [[
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 c = Texel(texture, texture_coords);
	return vec4(c.rgb * 1.25, c.a * 1.15) * color;
}
]]

local function unpremultiply(x, y, r, g, b, a)
	return r / a, g / a, b / a, a
end

local old_style = make_cache_table {
	"assets/image/tap_circle/red.png",
	"assets/image/tap_circle/green.png",
	"assets/image/tap_circle/cyan.png",
	"assets/image/tap_circle/blue.png",
	"assets/image/tap_circle/yellow.png",
	"assets/image/tap_circle/orange.png",
	"assets/image/tap_circle/pink.png",
	"assets/image/tap_circle/purple.png",
	"assets/image/tap_circle/gray.png",
	"assets/image/tap_circle/rainbow.png",
	"assets/image/tap_circle/black.png",
	
	Simultaneous = "assets/image/tap_circle/timing_normal.png",
	Slide = "assets/image/tap_circle/slide_normal.png"
}
local new_style = make_cache_table {
	"assets/image/tap_circle/pink_v5.png",
	"assets/image/tap_circle/green_v5.png",
	"assets/image/tap_circle/cyan_v5.png",
	"assets/image/tap_circle/blue_v5.png",
	"assets/image/tap_circle/yellow_v5.png",
	"assets/image/tap_circle/orange_v5.png",
	"assets/image/tap_circle/red_v5.png",
	"assets/image/tap_circle/purple_v5.png",
	"assets/image/tap_circle/gray_v5.png",
	"assets/image/tap_circle/rainbow_v5.png",
	"assets/image/tap_circle/black_v5.png",
	
	Simultaneous = "assets/image/tap_circle/timing_v5.png"
}
local new_style_slide = make_cache_table {
	"assets/image/tap_circle/slide_pink.png",
	"assets/image/tap_circle/slide_green.png",
	"assets/image/tap_circle/slide_cyan.png",
	"assets/image/tap_circle/slide_blue.png",
	"assets/image/tap_circle/slide_yellow.png",
	"assets/image/tap_circle/slide_orange.png",
	"assets/image/tap_circle/slide_red.png",
	"assets/image/tap_circle/slide_purple.png",
	"assets/image/tap_circle/slide_gray.png",
	"assets/image/tap_circle/slide_rainbow.png",
	"assets/image/tap_circle/slide_black.png"
}

local new_style_rotation = {
	math.rad(-90),
	math.rad(-67.5),
	math.rad(-45),
	math.rad(-22.5),
	0,
	math.rad(22.5),
	math.rad(45),
	math.rad(67.5),
	math.rad(90)
}
local star_icon = AquaShine.LoadImage("assets/image/tap_circle/star.png")
local color_temp = table.new(4, 0)

local function drawNoteBase(image, this, rot)
	love.graphics.draw(image, this.FirstCircle[1], this.FirstCircle[2], rot or 0, this.CircleScale, this.CircleScale, 64, 64)
end

function NoteImageLoader.DrawNoteV5Style(this)
	local noteimg, noteimg_swing
	color_temp[1] = 1
	color_temp[2] = 1
	color_temp[3] = 1
	color_temp[4] = DEPLS.LiveOpacity * this.Opacity
	
	if bit.band(this.Attribute, 15) == 15 then
		noteimg = new_style[9]
		noteimg_swing = new_style_slide[9]
		color_temp[1] = bit.band(bit.rshift(this.Attribute, 23), 511) / 255
		color_temp[2] = bit.band(bit.rshift(this.Attribute, 14), 511) / 255
		color_temp[3] = bit.band(bit.rshift(this.Attribute, 5), 511) / 255
	else
		noteimg = assert(new_style[this.Attribute], "Invalid note attribute")
		noteimg_swing = new_style_slide[this.Attribute]
	end
	
	love.graphics.setColor(color_temp)
	love.graphics.setShader(newstyle_opacitymul)
	if this.SlideNote then
		-- If it's swing, simply draw the pre-generated image
		drawNoteBase(noteimg_swing, this, new_style_rotation[this.Position])
	else
		-- Otherwise, normal note
		drawNoteBase(noteimg, this, new_style_rotation[this.Position])
	end
	love.graphics.setShader()
	love.graphics.setColor(1, 1, 1, color_temp[4])
	
	if this.TokenNote then
		drawNoteBase(DEPLS.Images.Note.Token, this)
	elseif this.StarNote then
		drawNoteBase(star_icon, this)
	end
	
	if this.SimulNote then
		drawNoteBase(new_style.Simultaneous, this)
	end
end

function NoteImageLoader.DrawNoteOldStyle(this)
	local noteimg
	color_temp[1] = 1
	color_temp[2] = 1
	color_temp[3] = 1
	color_temp[4] = DEPLS.LiveOpacity * this.Opacity
	
	if bit.band(this.Attribute, 15) == 15 then
		noteimg = old_style[9]
		color_temp[1] = bit.band(bit.rshift(this.Attribute, 23), 511) / 255
		color_temp[2] = bit.band(bit.rshift(this.Attribute, 14), 511) / 255
		color_temp[3] = bit.band(bit.rshift(this.Attribute, 5), 511) / 255
	else
		noteimg = assert(old_style[this.Attribute], "Invalid note attribute")
	end
	
	love.graphics.setColor(color_temp)
	drawNoteBase(noteimg, this)
	love.graphics.setColor(1, 1, 1, color_temp[4])
	
	if this.TokenNote then
		drawNoteBase(DEPLS.Images.Note.Token, this)
	elseif this.StarNote then
		drawNoteBase(star_icon, this)
	end
	
	if this.SlideNote then
		drawNoteBase(old_style.Slide, this, this.Rotation)
	end
	
	if this.SimulNote then
		drawNoteBase(old_style.Simultaneous, this)
	end
end

local notes_draw_handler = {NoteImageLoader.DrawNoteOldStyle, NoteImageLoader.DrawNoteV5Style}

function NoteImageLoader.GetNoteImageFunction()
	local nstyle = AquaShine.GetCommandLineConfig("notestyle") or DEPLS.ForceNoteStyle
	return assert(notes_draw_handler[nstyle], "Invalid note style. Only 1 (old) or 2 (new) note styles are allowed")
end

return NoteImageLoader
