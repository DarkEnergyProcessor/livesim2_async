-- Insert beatmap process
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")

local Gamestate = require("gamestate")
local Util = require("util")
local L = require("language")

local beatmapProbe = require("game.beatmap.probe")

local beatmapProcess = Gamestate.create {
	images = {}, fonts = {}
}

local function askOverwrite(name)
	return love.window.showMessageBox(
		L"beatmapSelect:insert:overwrite",
		L("beatmapSelect:insert:overwriteDesc", {name = name}),
		{"Yes", "No", enterbutton = 1, escapebutton = 2},
		"warning"
	) == 1
end

function beatmapProcess.start(_, list)
	for i = 1, #list do
		local f
		if type(list[i]) == "string" then
			f = Util.newFileWrapper(list[i], "rb")
		elseif list[i]:open("r") then
			f = list[i]
		end

		if f then
			local filename = Util.basename(f:getFilename())

			if beatmapProbe(f) then
				local there = Util.fileExists("beatmap/"..filename)
				if there and askOverwrite(filename) or not(there) then
					local fout = Util.newFileCompat("beatmap/"..filename, "w")
					if fout then
						f:seek(0)
						fout:write(f:read())
						fout:close()
					else
						love.window.showMessageBox("Error", "Cannot open file for writing", "error")
					end
				end
			else
				love.window.showMessageBox("Error", L("beatmapSelect:insert:errorFmt", {name = filename}), "error")
			end
		else
			love.window.showMessageBox("Error", "Cannot open file for reading", "error")
		end
	end

	Gamestate.replace(nil, "beatmapSelect")
end

return beatmapProcess
