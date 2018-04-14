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
extern bool enable;
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	if (!enable) return Texel(texture, texture_coords) * color;
	
	vec4 c = Texel(texture, texture_coords);
	return vec4(c.rgb * 1.25, c.a * 1.15) * color;
}
]]

local function unpremultiply(x, y, r, g, b, a)
	return r / a, g / a, b / a, a
end

local old_style = make_cache_table {
	"assets/image/tap_circle/default/red.png",
	"assets/image/tap_circle/default/green.png",
	"assets/image/tap_circle/default/cyan.png",
	"assets/image/tap_circle/default/blue.png",
	"assets/image/tap_circle/default/yellow.png",
	"assets/image/tap_circle/default/orange.png",
	"assets/image/tap_circle/default/pink.png",
	"assets/image/tap_circle/default/purple.png",
	"assets/image/tap_circle/default/gray.png",
	"assets/image/tap_circle/default/rainbow.png",
	"assets/image/tap_circle/default/black.png",
	
	Simultaneous = "assets/image/tap_circle/default/timing_normal.png",
	Slide = "assets/image/tap_circle/default/slide_normal.png"
}
local new_style = make_cache_table {
	"assets/image/tap_circle/neon/pink_v5.png",
	"assets/image/tap_circle/neon/green_v5.png",
	"assets/image/tap_circle/neon/cyan_v5.png",
	"assets/image/tap_circle/neon/blue_v5.png",
	"assets/image/tap_circle/neon/yellow_v5.png",
	"assets/image/tap_circle/neon/orange_v5.png",
	"assets/image/tap_circle/neon/red_v5.png",
	"assets/image/tap_circle/neon/purple_v5.png",
	"assets/image/tap_circle/neon/gray_v5.png",
	"assets/image/tap_circle/neon/rainbow_v5.png",
	"assets/image/tap_circle/neon/black_v5.png",
	
	Simultaneous = "assets/image/tap_circle/neon/timing_v5.png"
}
local new_style_slide = make_cache_table {
	"assets/image/tap_circle/neon/slide_pink.png",
	"assets/image/tap_circle/neon/slide_green.png",
	"assets/image/tap_circle/neon/slide_cyan.png",
	"assets/image/tap_circle/neon/slide_blue.png",
	"assets/image/tap_circle/neon/slide_yellow.png",
	"assets/image/tap_circle/neon/slide_orange.png",
	"assets/image/tap_circle/neon/slide_red.png",
	"assets/image/tap_circle/neon/slide_purple.png",
	"assets/image/tap_circle/neon/slide_gray.png",
	"assets/image/tap_circle/neon/slide_rainbow.png",
	"assets/image/tap_circle/neon/slide_black.png"
}

local matte_style = make_cache_table {
	"assets/image/tap_circle/matte/00.png",
	"assets/image/tap_circle/matte/01.png",
	"assets/image/tap_circle/matte/02.png",
	"assets/image/tap_circle/matte/06.png",
	"assets/image/tap_circle/matte/05.png",
	"assets/image/tap_circle/matte/04.png",
	"assets/image/tap_circle/matte/03.png",
	"assets/image/tap_circle/matte/07.png",
	"assets/image/tap_circle/matte/08.png",
	"assets/image/tap_circle/matte/09.png",
	"assets/image/tap_circle/matte/20.png",
	
	Simultaneous = "assets/image/tap_circle/matte/simul.png"
}

local matte_style_slide = make_cache_table {
	"assets/image/tap_circle/matte/10.png",
	"assets/image/tap_circle/matte/11.png",
	"assets/image/tap_circle/matte/12.png",
	"assets/image/tap_circle/matte/16.png",
	"assets/image/tap_circle/matte/15.png",
	"assets/image/tap_circle/matte/14.png",
	"assets/image/tap_circle/matte/13.png",
	"assets/image/tap_circle/matte/17.png",
	"assets/image/tap_circle/matte/18.png",
	"assets/image/tap_circle/matte/19.png",
	"assets/image/tap_circle/matte/21.png"
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

function NoteImageLoader.DrawNoteMatteStyle(this)
	local noteimg, noteimg_swing
	color_temp[1] = 1
	color_temp[2] = 1
	color_temp[3] = 1
	color_temp[4] = DEPLS.LiveOpacity * this.Opacity
	
	if bit.band(this.Attribute, 15) == 15 then
		noteimg = matte_style[9]
		noteimg_swing = matte_style_slide[9]
		color_temp[1] = bit.band(bit.rshift(this.Attribute, 23), 511) / 255
		color_temp[2] = bit.band(bit.rshift(this.Attribute, 14), 511) / 255
		color_temp[3] = bit.band(bit.rshift(this.Attribute, 5), 511) / 255
	else
		noteimg = assert(matte_style[this.Attribute], "Invalid note attribute")
		noteimg_swing = matte_style_slide[this.Attribute]
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
		drawNoteBase(noteimg_swing, this, this.Rotation)
	end
	
	if this.SimulNote then
		love.graphics.draw(
			matte_style.Simultaneous,
			this.FirstCircle[1],
			this.FirstCircle[2],
			0, this.CircleScale, this.CircleScale,
			128, 128
		)
	end
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
	newstyle_opacitymul:send("enable", true)
	if this.SlideNote then
		-- If it's swing, simply draw the pre-generated image
		drawNoteBase(noteimg_swing, this, this.Rotation)
	else
		-- Otherwise, normal note
		drawNoteBase(noteimg, this, new_style_rotation[this.Position])
	end
	newstyle_opacitymul:send("enable", false)
	love.graphics.setColor(1, 1, 1, color_temp[4])

	if this.TokenNote then
		drawNoteBase(DEPLS.Images.Note.Token, this)
	elseif this.StarNote then
		drawNoteBase(star_icon, this)
	end

	if this.SimulNote then
		drawNoteBase(new_style.Simultaneous, this)
	end
	
	love.graphics.setShader()
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

local notes_draw_handler = {
	NoteImageLoader.DrawNoteOldStyle,
	NoteImageLoader.DrawNoteV5Style,
	NoteImageLoader.DrawNoteMatteStyle
}

function NoteImageLoader.GetNoteImageFunction()
	local nstyle = AquaShine.GetCommandLineConfig("notestyle") or DEPLS.ForceNoteStyle
	return assert(notes_draw_handler[nstyle], "Invalid note style")
end

return NoteImageLoader
