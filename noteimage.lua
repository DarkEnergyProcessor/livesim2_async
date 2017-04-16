local love = love
local bit = require("bit")
local DEPLS = ({...})[1]

local NoteImageLoader = {}

local old_style = {
	love.graphics.newImage("image/tap_circle/tap_circle-0.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-4.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-8.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-12.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-16.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-20.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-24.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-28.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-32.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-36.png"),
	love.graphics.newImage("image/tap_circle/tap_circle-40.png")
}
local new_style = {
	love.graphics.newImage("image/tap_circle/v5/pink.png"),
	love.graphics.newImage("image/tap_circle/v5/green.png"),
	love.graphics.newImage("image/tap_circle/v5/aqua.png"),
	love.graphics.newImage("image/tap_circle/v5/blue.png"),
	love.graphics.newImage("image/tap_circle/v5/yellow.png"),
	love.graphics.newImage("image/tap_circle/v5/orange.png"),
	love.graphics.newImage("image/tap_circle/v5/red.png"),
	love.graphics.newImage("image/tap_circle/v5/purple.png"),
	love.graphics.newImage("image/tap_circle/v5/silver.png"),
	love.graphics.newImage("image/tap_circle/v5/rainbow.png"),
	love.graphics.newImage("image/tap_circle/v5/black.png")
}
local new_style_quad = {
	normal = love.graphics.newQuad(0, 0, 128, 128, 768, 128),
	simultaneous = love.graphics.newQuad(128, 0, 128, 128, 768, 128),
	star = love.graphics.newQuad(256, 0, 128, 128, 768, 128),
	star_simultaneous = love.graphics.newQuad(384, 0, 128, 128, 768, 128),
	slide = love.graphics.newQuad(512, 0, 128, 128, 768, 128),
	slide_simultaneous = love.graphics.newQuad(640, 0, 128, 128, 768, 128)
}
local note_icons_quad = {
	simultaneous = love.graphics.newQuad(128, 0, 128, 128, 512, 128),
	star = love.graphics.newQuad(256, 0, 128, 128, 512, 128),
	star_simultaneous = love.graphics.newQuad(384, 0, 128, 128, 512, 128)
}
local note_icons = love.graphics.newImage("image/tap_circle/v5/icons.png")
local image_cache = {}

function NoteImageLoader.CreateNoteV5Style(attribute, is_token, is_simultaneous, is_star, is_slide)
	local noteimg
	local cbf_ext = bit.band(attribute, 15) == 15
	
	if cbf_ext then
		noteimg = new_style[9]
	else
		noteimg = assert(new_style[attribute], "Invalid note attribute")
	end
	
	local cache_name = string.format("new_%08x%d%d%d%d%d", attribute,
		cbf_ext and 1 or 0,
		is_token and 1 or 0,
		is_simultaneous and 1 or 0,
		is_star and 1 or 0,
		is_slide and 1 or 0
	)
	
	if image_cache[cache_name] then
		return image_cache[cache_name]
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
			love.graphics.draw(noteimg, new_style_quad.slide)
			love.graphics.setColor(255, 255, 255)
			
			if is_simultaneous then
				love.graphics.draw(note_icons, note_icons_quad.simultaneous)
			end
		else
			love.graphics.draw(noteimg, new_style_quad.normal)
			love.graphics.setColor(255, 255, 255)
			
			if is_token then
				love.graphics.draw(DEPLS.Images.Note.Token)
				
				if is_simultaneous then
					love.graphics.draw(note_icons, note_icons_quad.simultaneous)
				end
			elseif is_star then
				love.graphics.draw(note_icons, is_simultaneous and note_icons_quad.star_simultaneous or note_icons_quad.star)
			elseif is_simultaneous then
				love.graphics.draw(note_icons, note_icons_quad.simultaneous)
			end
		end
	else
		if is_token then
			love.graphics.draw(noteimg, new_style_quad.normal)
			love.graphics.draw(DEPLS.Images.Note.Token)
			
			if is_simultaneous then
				love.graphics.draw(note_icons, note_icons_quad.simultaneous)
			end
		elseif is_slide then
			love.graphics.draw(noteimg, is_simultaneous and new_style_quad.slide_simultaneous or new_style_quad.slide)
		elseif is_star then
			love.graphics.draw(noteimg, is_simultaneous and new_style_quad.star_simultaneous or new_style_quad.star)
		else
			love.graphics.draw(noteimg, new_style_quad.normal)
			
			if is_simultaneous then
				love.graphics.draw(note_icons, note_icons_quad.simultaneous)
			end
		end
	end
	
	love.graphics.pop()
	
	canvas_composition = love.graphics.newImage(canvas_composition:newImageData())
	image_cache[cache_name] = canvas_composition
	return canvas_composition
end

function NoteImageLoader.CreateNoteOldStyle(attribute, is_token, is_simultaneous, is_star, is_slide)
	local noteimg
	local cbf_ext = bit.band(attribute, 15) == 15
	local cache_name = string.format("old_%08x%d%d%d%d%d", attribute,
		cbf_ext and 1 or 0,
		is_token and 1 or 0,
		is_simultaneous and 1 or 0,
		is_star and 1 or 0,
		is_slide and 1 or 0
	)
	
	if cbf_ext then
		noteimg = old_style[9]
	else
		noteimg = assert(old_style[attribute], "Invalid note attribute")
	end
	
	if image_cache[cache_name] then
		return image_cache[cache_name]
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
		love.graphics.draw(noteimg)
	else
		love.graphics.draw(noteimg)
	end
	
	love.graphics.setColor(255, 255, 255)
	
	if is_token then
		love.graphics.draw(DEPLS.Images.Note.Token)
	elseif is_star then
		love.graphics.draw(DEPLS.Images.Note.Star)
	elseif is_slide then
		love.graphics.draw(DEPLS.Images.Note.Slide, 0, 0, 0, 2, 2)
	end
	
	if is_simultaneous then
		love.graphics.draw(DEPLS.Images.Note.Simultaneous)
	end
	
	love.graphics.pop()
	
	canvas_composition = love.graphics.newImage(canvas_composition:newImageData())
	image_cache[cache_name] = canvas_composition
	return canvas_composition
end

local notes_handler = {NoteImageLoader.CreateNoteOldStyle, NoteImageLoader.CreateNoteV5Style}
function NoteImageLoader.LoadNoteImage(attribute, is_token, is_simultaneous, is_star, is_slide)
	return assert(notes_handler[DEPLS.ForceNoteStyle], "Invalid note style. Only 1 (old) or 2 (new) note styles are allowed")(attribute, is_token, is_simultaneous, is_star, is_slide)
end

return NoteImageLoader
