-- Live Simulator: 2 bootstrap code with AquaShine
-- AquaShine is a entry point handler/loader specially written for Live Simulator: 2.
-- Since AquaShine is special for Live Simulator: 2, it's not available as standalone Lua script.
-- Please see docs/AquaShine.md for more information.

DEPLS_VERSION = "1.0.1-pre1"

----------------------
-- AquaShine loader --
----------------------
AquaShine = assert(love.filesystem.load("AquaShine.lua"))({
	Entries = {
		livesim = {1, "livesim.lua"},
		settings = {0, "setting_view.lua"},
		main_menu = {0, "main_menu.lua"},
		beatmap_select = {0, "select_beatmap.lua"},
		unit_editor = {0, "unit_editor.lua"},
		about = {0, "about_screen.lua"},
		render = {3, "render_livesim.lua"},
		noteloader = {1, "invoke_noteloader.lua"},
	},
	DefaultEntry = "main_menu",
	Width = 960,	-- Letterboxing
	Height = 640	-- Letterboxing
})


--------------------------------
-- Yohane Initialization Code --
--------------------------------
local Yohane = require("Yohane")

Yohane.Platform.ResolveImage = AquaShine.LoadImage
function Yohane.Platform.ResolveAudio(path)
	return love.audio.newSource(AquaShine.LoadAudio(path .. ".wav"))
end

function Yohane.Platform.CloneImage(image_handle)
	return image_handle
end

function Yohane.Platform.CloneAudio(audio)
	if audio then
		return audio:clone()
	end
	
	return nil
end

function Yohane.Platform.PlayAudio(audio)
	if audio then
		audio:stop()
		audio:play()
	end
end

function Yohane.Platform.Draw(drawdatalist)
	local r, g, b, a = love.graphics.getColor()
	
	for _, drawdata in ipairs(drawdatalist) do
		if drawdata.image then
			love.graphics.setColor(drawdata.r, drawdata.g, drawdata.b, drawdata.a)
			love.graphics.draw(drawdata.image, drawdata.x, drawdata.y, drawdata.rotation, drawdata.scaleX, drawdata.scaleY)
		end
	end
	
	love.graphics.setColor(r, g, b, a)
end

function Yohane.Platform.OpenReadFile(fn)
	return assert(love.filesystem.newFile(fn, "r"))
end

Yohane.Init(love.filesystem.load)

----------------------------
-- Force Create Directory --
----------------------------
assert(love.filesystem.createDirectory("audio"), "Failed to create directory")
assert(love.filesystem.createDirectory("beatmap"), "Failed to create directory")
assert(love.filesystem.createDirectory("screenshots"), "Failed to create directory")
assert(love.filesystem.createDirectory("unit_icon"), "Failed to create directory")
assert(love.filesystem.createDirectory("temp"), "Failed to create directory")
