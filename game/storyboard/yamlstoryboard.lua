-- YAML storyboard loader
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local yaml = require("libs.tinyyaml")
local Luaoop = require("libs.Luaoop")
local timer = require("libs.hump.timer")

local util = require("util")

local baseStoryboard = require("game.storyboard.base")

local yamlStoryboard = Luaoop.class("Livesim2.Storyboard.YAML", baseStoryboard)



local function loadDefaultFont(size)
	local roboto = love.graphics.newFont("fonts/Roboto-Regular.ttf", size)
	roboto:setFallbacks(love.graphics.newFont("fonts/MTLmr3m.ttf", size))
	return roboto
end

function yamlStoryboard:__construct(storyboardData, info)
	-- info parameter contains:
	-- ["path"] - beatmap path (optional)
	-- ["data"] - additional embedded data where value is FileData (optional)
	-- ["background"] - current background
	-- ["unit"] - unit image list, index from 1..9

	local storyData = yaml.parse(storyboardData)

	-- Setup variables
	self.data = {}
	self.path = info.path
	if self.path and self.path:sub(-1) ~= "/" then
		self.path = self.path.."/"
	end

	self.timing = {}
	self.events = {}
	self.drawable = {}
	self.timer = timer.new()

	-- Add FileDatas
	for i = 1, #info.data do
		self.data[i] = info.data[i]
		self.data[info.data[i]:getFilename()] = info.data[i]
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
			r = v.red or 255,
			g = v.green or 255,
			b = v.blue or 255,
			a = v.alpha or 255,
			x = v.x or 0,
			y = v.y or 0,
			rot = v.r or 0,
			sx = v.sx or 1,
			sy = v.sy or 1,
			ox = v.ox or 0,
			oy = v.oy or 0,
			kx = v.kx or 0,
			ky = v.ky or 0,
			text = v.text or "",
			tweenParams = {}
		}

		if v.draw == "image" then
			if not(v.image) then
				error("init #"..i.." image is mandatory")
			end
			drawobj.imageObject = love.graphics.newImage(self.data[v.image] or self.path..v.image, {mipmaps = true})
		elseif v.draw == "text" then
			local font
			if v.font then
				local fname, size = v.font:match("([^:]+):?(%d*)")
				size = (#size == 0 or not(size)) and 12 or assert(tonumber(size), "invalid size")

				if fname == "__default" then
					-- Use defaont
					font = loadDefaultFont(size)
				elseif fname == "__mtlmr3m" then
					-- Use "inverse" default
					font = love.graphics.newFont("fonts/MTLmr3m.ttf", size)
					font:setFallbacks(love.graphics.newFont("fonts/Roboto-Regular.ttf", size))
				else
					-- Load specified font
					font = love.graphics.newFont(self.data[fname] or self.path..fname, size)
				end
			else
				-- Use default
				font = loadDefaultFont()
			end
			drawobj.textObject = love.graphics.newText(font, drawobj.text)
		end

		self.drawable[v.name] = drawobj
	end

	-- TODO: Load skill

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
	table.sort(self.timing, function(a, b) return a.time < b.time end)
end

return yamlStoryboard
