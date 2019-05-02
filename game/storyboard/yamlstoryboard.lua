-- YAML storyboard loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local yaml = require("libs.tinyyaml")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")

local audioManager = require("audio_manager")
local color = require("color")
local log = require("logging")
local util = require("util")

local baseStoryboard = require("game.storyboard.base")

local yamlStoryboard = Luaoop.class("Livesim2.Storyboard.YAML", baseStoryboard)

local function loadDefaultFont(size)
	local roboto = love.graphics.newFont("fonts/Roboto-Regular.ttf", size)
	roboto:setFallbacks(love.graphics.newFont("fonts/NotoSansCJKjp-Regular.woff", size))
	return roboto
end

function yamlStoryboard:__construct(storyboardData, info)
	-- info parameter contains:
	-- ["path"] - beatmap path (optional)
	-- ["data"] - additional embedded data where value is FileData (optional)
	-- ["background"] - current background
	-- ["unit"] - unit image list, index from 1..9
	-- ["skill"] - skill callback function
	-- ["seed"] - random seed in {low, high}

	local storyData = yaml.parse(storyboardData)

	-- Setup variables
	self.data = {}
	self.path = info.path
	self.background = info.background
	self.unit = info.unit
	if self.path and self.path:sub(-1) ~= "/" then
		self.path = self.path.."/"
	end

	self.elapsedTime = 0
	self.timing = {}
	self.events = {}
	self.drawable = {}
	self.drawing = {}
	self.timer = timer.new()
	self.emitEvent = {}
	self.skillCallback = assert(info.skill)

	-- Add FileDatas
	if info.data then
		for i = 1, #info.data do
			self.data[i] = info.data[i]
			self.data[info.data[i]:getFilename()] = info.data[i]
		end
	end

	-- Load drawables
	for i, v in ipairs(storyData.init) do
		if not(v.name and v.name ~= yaml.null) then
			error("init #"..i.." name is mandatory")
		end

		if v.draw ~= "image" and v.draw ~= "text" then
			error("init #"..i.." invalid draw type")
		end

		if self.drawable[v.name] then
			-- No redefinition
			error("init #"..i.." name already exist")
		elseif v.name:sub(1, 2) == "__" then
			-- No reserved name
			error("init #"..i.." name is reserved")
		end

		local drawobj = {
			red = v.red or 255,
			green = v.green or 255,
			blue = v.blue or 255,
			alpha = v.alpha or 255,
			x = v.x or 0,
			y = v.y or 0,
			r = v.r or 0,
			sx = v.sx or 1,
			sy = v.sy or 1,
			ox = v.ox or 0,
			oy = v.oy or 0,
			kx = v.kx or 0,
			ky = v.ky or 0,
			text = v.text or "",
			type = v.draw,
			tweenParams = {}
		}

		if v.draw == "image" then
			if not(v.image) then
				error("init #"..i.." image is mandatory")
			end

			if self.path then
				drawobj.drawable = love.graphics.newImage(self.data[v.image] or self.path..v.image, {mipmaps = true})
			else
				drawobj.drawable = love.graphics.newImage(self.data[v.image], {mipmaps = true})
			end
		elseif v.draw == "text" then
			local font
			if v.font then
				local fname, size = v.font:match("([^:]+):?(%d*)")
				size = (#size == 0 or not(size)) and 12 or assert(tonumber(size), "invalid size")

				if fname == "__default" or fname == "__fallback" then
					-- Use default
					font = loadDefaultFont(size)
				else
					-- Load specified font
					if self.path then
						font = love.graphics.newFont(self.data[fname] or self.path..fname, size)
					else
						font = love.graphics.newFont(self.data[fname], size)
					end
				end
			else
				-- Use default
				font = loadDefaultFont()
			end
			drawobj.drawable = love.graphics.newText(font, drawobj.text)
		end

		self.drawable[v.name] = drawobj
	end

	-- Pseudo-targets __unit_<n>
	for i = 1, 9 do
		self.drawable["__unit_"..i] = {
			drawable = assert(info.background, "invalid unit"),
			red = 255, green = 255, blue = 255, alpha = 255,
			x = 0, y = 0, r = 0,
			sx = 1, sy = 1,
			ox = 0, oy = 0,
			kx = 0, ky = 0,
			text = "",
			type = "image",
			tweenParams = {}
		}
	end
	-- Pseudo-target __background
	self.drawable.__background = {
		drawable = assert(info.background, "invalid background"),
		red = 255, green = 255, blue = 255, alpha = 255,
		x = 0, y = 0, rot = 0,
		sx = 1, sy = 1,
		ox = 0, oy = 0,
		kx = 0, ky = 0,
		text = "",
		type = "image",
		tweenParams = {}
	}
	self.drawing[1] = self.drawable.__background

	-- Load skill
	if storyData.skill then
		for _, v in ipairs(storyData.skill) do
			local skillData = {
				type = v.type,
				chance = util.clamp(v.chance, 0, 1),
				rarity = v.rarity:lower(),
				value = v.value,
				unit = v.index
			}

			if v.draw then
				skillData.image = assert(self.drawable[v.draw], "target drawable not exist").drawable
			end

			if v.audio then
				skillData.audio = self:loadAudio(v.audio, "voice")
			end

			-- Load condition
			local condition = assert(v.condition, "condition does not exist")
			local condTable = {}
			local hasCondition = false

			-- This is expensive
			for k, v2 in pairs(condition) do
				if k == "emit" then
					assert(self.events[v2] == nil, "event name already occupied")
					self.events[v2] = {
						type = "skill",
						data = skillData
					}
				else
					hasCondition = true
					condTable[k] = v2
				end
			end

			if hasCondition then
				self.skillCallback("register", skillData, condTable)
			end
		end
	end

	local counter = 1
	-- helper function
	local function handleEvent(i, time, v)
		if v.type ~= "draw" and v.type ~= "undraw" and v.type ~= "set" and v.type ~= "emit" then
			error("storyboard #"..i.." invalid type", 2)
		end

		if not(v.target) then
			error("storyboard #"..i.." target is mandatory")
		end

		if v.type == "emit" and not(self.events[v.target]) then
			error("storyboard #"..i.." target doesn't exist")
		elseif not(self.drawable[v.target]) then
			error("storyboard #"..i.." target doesn't exist")
		end

		-- Add
		local t = util.deepCopy(v)
		counter = counter + 1
		t.index = counter
		t.time = time
		self.timing[#self.timing + 1] = t
	end

	-- Load events
	for i, v in ipairs(storyData.storyboard) do
		if type(v.time) ~= "number" then
			error("storyboard #"..i.." time is mandatory and must be number")
		end

		if v["do"] then
			for j = 1, #v["do"] do
				handleEvent(i, v.time, v["do"][j])
			end
		else
			handleEvent(i, v.time, v)
		end
	end

	-- Sort events
	table.sort(self.timing, function(a, b)
		if a.time == b.time then
			return a.index < b.index
		else
			return a.time < b.time
		end
	end)
end

local tweenableValue = {
	"x", "y", "r", "sx", "sy", "ox", "oy", "kx", "ky",
	"red", "green", "blue", "alpha"
}

local changeableValue = {
	"x", "y", "r", "sx", "sy", "ox", "oy", "kx", "ky",
	"red", "green", "blue", "alpha", "text"
}

function yamlStoryboard:handleEvent(ev)
	if ev.type == "emit" then
		local event = assert(self.events[ev.target], "event doesn't exist")
		if event.type == "skill" then
			self.skillCallback(
				"trigger",
				event.data.type,
				event.data.value,
				event.data.unit,
				event.data.rarity,
				event.data.image,
				event.data.audio
			)
		end
	else
		local target = assert(self.drawable[ev.target], "target doesn't exist")

		local found = false
		for i = 1, #self.drawing do
			if self.drawing[i] == target then
				found = true

				if ev.type == "undraw" then
					table.remove(self.drawing, i)
				end

				break
			end
		end

		if not(found) and ev.type == "draw" then
			self.drawing[#self.drawing + 1] = target
		end

		-- This codepath should be taken for "set" mode
		-- ("draw" and "undraw" also use "set" mode)
		for k, v in pairs(ev) do
			if k ~= "type" and k ~= "time" and k ~= "target" and util.isValueInArray(changeableValue, k) then
				if tostring(v):find("tween", 1, true) and util.isValueInArray(tweenableValue, k) then
					-- The format is "tween %d+ in %d+ seconds|ms"
					local ok = true
					local dest, duration, unit = tostring(v):match("tween (%d+) in (%d+) ([ms|seconds]+)")
					if unit == "ms" then
						duration = tonumber(duration) / 1000
					elseif unit ~= "seconds" then
						log.warningf("yamlstoryboard", "invalid time unit '%s', ignored", unit)
						ok = false
					end

					if ok then
						if target.tweenParams[k] then
							self.timer:cancel(target.tweenParams[k])
						end
						target.tweenParams[k] = self.timer:tween(tonumber(duration), target, {[k] = tonumber(dest)})
					end
				else
					-- Normal set, also disable tween
					if target.tweenParams[k] then
						self.timer:cancel(target.tweenParams[k])
						target.tweenParams[k] = nil
					end
					target[k] = tonumber(v) or v

					-- Specialization, for text, also recreate the Text object
					if k == "text" and target.type == "text" then
						target.drawable:clear()
						target.drawable:add(target.text)
					end
				end
			end
		end
	end
end

function yamlStoryboard:loadAudio(path, kind)
	if path == nil then return nil end

	if self.data[path] then
		return audioManager.newAudioDirect(love.sound.newDecoder(self.data[path]), kind)
	elseif self.path then
		if util.fileExists(self.path..path) then
			return audioManager.newAudio(self.path..path, kind)
		end
	end

	return nil
end

function yamlStoryboard:update(dt)
	self.elapsedTime = self.elapsedTime + dt
	self.timer:update(dt)

	local length = #self.timing
	local index = 1
	local left = length

	for i = 1, length do
		local ev = self.timing[i]

		if self.elapsedTime >= ev.time then
			self:handleEvent(ev)
			left = left - 1
		else
			self.timing[index] = ev
			index = index + 1
		end
	end

	-- Remove events
	for i = left + 1, length do
		self.timing[i] = nil
	end
end

function yamlStoryboard:draw()
	for i = 1, #self.drawing do
		local d = self.drawing[i]

		if d.alpha >= 0.0001 then
			love.graphics.setColor(color.compat(d.red, d.green, d.blue, d.alpha / 255))
			love.graphics.draw(d.drawable, d.x, d.y, d.r, d.sx, d.sy, d.ox, d.oy, d.kx, d.ky)
		end
	end
end

function yamlStoryboard.callback()
	-- NOOP atm
end

return yamlStoryboard
