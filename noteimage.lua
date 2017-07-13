-- Note image handling
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = love
local bit = require("bit")
local DEPLS, AquaShine = ...
local NoteImageLoader = {}

local function make_cache_table(link)
	return setmetatable({}, {__index = function(_, var)
		return AquaShine.LoadImage(link[var])
	end})
end

local newstyle_opacitymul = love.graphics.newShader [[
vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords)
{
	vec4 c = Texel(texture, texture_coords);
	return vec4(c.rgb, (c.a + log(1.0 + c.a)) * 0.75) * color;
}
]]

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

function NoteImageLoader.CreateNoteV5Style(attribute, idx, is_token, is_simultaneous, is_star, is_slide, rot)
	local noteimg
	local cbf_ext = bit.band(attribute, 15) == 15
	
	if cbf_ext then
		noteimg = new_style[9]
	else
		noteimg = assert(new_style[attribute], "Invalid note attribute")
	end
	
	if is_slide then idx = 0 end	-- Cache optimization
	
	local cache_name = string.format("new%d_%08x%d%d%d%d%d%.2f", idx, attribute,
		cbf_ext and 1 or 0,
		is_token and 1 or 0,
		is_simultaneous and 1 or 0,
		is_star and 1 or 0,
		is_slide and 1 or 0,
		rot or 0
	)
	
	if AquaShine.CacheTable[cache_name] then
		return AquaShine.CacheTable[cache_name]
	end
	
	local canvas_composition = love.graphics.newCanvas(128, 128)
	
	love.graphics.push("all")
	love.graphics.setCanvas(canvas_composition)
	
	if cbf_ext then
		love.graphics.setColor(
			bit.band(bit.rshift(attribute, 23), 511),
			bit.band(bit.rshift(attribute, 14), 511),
			bit.band(bit.rshift(attribute, 5), 511)
		)
		
		if is_slide then
			love.graphics.setShader(newstyle_opacitymul)
			love.graphics.draw(new_style_slide[9], 64, 64, 0, 1, 1, 64, 64)
			love.graphics.setColor(255, 255, 255)
			love.graphics.setShader()
			
			if is_token then
				love.graphics.draw(DEPLS.Images.Note.Token, 64, 64, -rot, 1, 1, 64, 64)
			end
			
			if is_simultaneous then
				love.graphics.draw(new_style.Simultaneous, 64, 64, -rot, 1, 1, 64, 64)
			end
		else
			love.graphics.setShader(newstyle_opacitymul)
			love.graphics.draw(noteimg, 64, 64, new_style_rotation[idx], 1, 1, 64, 64)
			love.graphics.setShader()
			love.graphics.setColor(255, 255, 255)
			
			if is_token then
				love.graphics.draw(DEPLS.Images.Note.Token)
			elseif is_star then
				love.graphics.draw(star_icon)
			end
			
			if is_simultaneous then
				love.graphics.draw(new_style.Simultaneous)
			end
		end
	else
		if is_slide then
			love.graphics.setShader(newstyle_opacitymul)
			love.graphics.draw(new_style_slide[attribute], 64, 64, 0, 1, 1, 64, 64)
			love.graphics.setShader()
			
			if is_token then
				love.graphics.draw(DEPLS.Images.Note.Token)
			end
			
			if is_simultaneous then
				love.graphics.draw(new_style.Simultaneous, 64, 64, -rot, 1, 1, 64, 64)
			end
		else
			love.graphics.setShader(newstyle_opacitymul)
			love.graphics.draw(noteimg, 64, 64, new_style_rotation[idx], 1, 1, 64, 64)
			love.graphics.setShader()
			
			if is_token then
				love.graphics.draw(DEPLS.Images.Note.Token)
			elseif is_star then
				love.graphics.draw(star_icon)
			end
			
			if is_simultaneous then
				love.graphics.draw(new_style.Simultaneous)
			end
		end
	end
	
	love.graphics.pop()
	
	canvas_composition = love.graphics.newImage(canvas_composition:newImageData())
	AquaShine.CacheTable[cache_name] = canvas_composition
	return canvas_composition
end

function NoteImageLoader.CreateNoteOldStyle(attribute, idx, is_token, is_simultaneous, is_star, is_slide, rot)
	rot = rot or 0
	
	local noteimg
	local cbf_ext = bit.band(attribute, 15) == 15
	local cache_name = string.format("old_%08x%d%d%d%d%d%.2f", attribute,
		cbf_ext and 1 or 0,
		is_token and 1 or 0,
		is_simultaneous and 1 or 0,
		is_star and 1 or 0,
		is_slide and 1 or 0,
		rot
	)
	
	if cbf_ext then
		noteimg = old_style[9]
	else
		noteimg = assert(old_style[attribute], "Invalid note attribute")
	end
	
	if AquaShine.CacheTable[cache_name] then
		return AquaShine.CacheTable[cache_name]
	end
	
	local canvas_composition = love.graphics.newCanvas(128, 128)
	
	love.graphics.push("all")
	love.graphics.setCanvas(canvas_composition)
	
	if cbf_ext then
		love.graphics.setColor(
			bit.band(bit.rshift(attribute, 23), 511),
			bit.band(bit.rshift(attribute, 14), 511),
			bit.band(bit.rshift(attribute, 5), 511)
		)
	end
	
	love.graphics.draw(noteimg, 64, 64, -rot, 1, 1, 64, 64)
	love.graphics.setColor(255, 255, 255)
	
	if is_token then
		love.graphics.draw(DEPLS.Images.Note.Token)
	elseif is_star then
		love.graphics.draw(star_icon)
	end
	
	if is_slide then
		love.graphics.draw(old_style.Slide)
	end
	
	if is_simultaneous then
		love.graphics.draw(old_style.Simultaneous, 64, 64, -rot, 1, 1, 64, 64)
	end
	
	love.graphics.pop()
	
	canvas_composition = love.graphics.newImage(canvas_composition:newImageData())
	AquaShine.CacheTable[cache_name] = canvas_composition
	return canvas_composition
end

local notes_handler = {NoteImageLoader.CreateNoteOldStyle, NoteImageLoader.CreateNoteV5Style}
function NoteImageLoader.LoadNoteImage(attribute, idx, is_token, is_simultaneous, is_star, is_slide, rot)
	local nstyle = AquaShine.GetCommandLineConfig("notestyle") or DEPLS.ForceNoteStyle
	
	return assert(notes_handler[nstyle], "Invalid note style. Only 1 (old) or 2 (new) note styles are allowed")(attribute, idx, is_token, is_simultaneous, is_star, is_slide, rot)
end

return NoteImageLoader
