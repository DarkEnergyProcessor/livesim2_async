-- Change Units menu
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local async = require("async")
local color = require("color")
local setting = require("setting")
local util = require("util")
local L = require("language")

local gamestate = require("gamestate")
local loadingInstance = require("loading_instance")

local lily = require("libs.lily")
--local gui = require("libs.fusion-ui")

local backgroundLoader = require("game.background_loader")
local backNavigation = require("game.ui.back_navigation")
local imageButton = require("game.ui.image_button")

local mipmap = {mipmaps = true}

local changeUnits = gamestate.create {
	images = {
		dummyUnit = {"assets/image/dummy.png", mipmap}
	},
	fonts = {
		main = {"fonts/MTLmr3m.ttf", 22}
	},
	audios = {}
}

local idolPosition = {
	{816+64, 96+64 },
	{785+64, 249+64},
	{698+64, 378+64},
	{569+64, 465+64},
	{416+64, 496+64},
	{262+64, 465+64},
	{133+64, 378+64},
	{46+64 , 249+64},
	{16+64 , 96+64 },
}

local function leave()
	return gamestate.leave(loadingInstance.getInstance())
end

function changeUnits:load()
	if self.data.changeUnitText == nil then
		local t = love.graphics.newText(self.assets.fonts.main)
		for i = 1, 0, -1 do
			local c = 255 - i * 255
			local ct = {color.compat(c, c, c, 1)}
			t:add({ct, "Click unit icon to change."}, 337 + i, 160 + i)
			t:add({ct, "Please note that some beatmap"}, 320.5 + i, 182 + i)
			t:add({ct, "can override unit icon shown in here"}, 282 + i, 204 + i)
			t:add({ct, "Press OK to apply changes,"}, 337 + i, 276 + i)
			t:add({ct, "Cancel to discard any changes"}, 320.5 + i, 298 + i)
			t:add({ct, "Back to discard any changes and back to"}, 265.5 + i, 320 + i)
			t:add({ct, "Live Simulator: 2 main menu"}, 331.5 + i, 342 + i)
		end
		self.data.changeUnitText = t
	end
	if self.data.background == nil then
		self.data.background = backgroundLoader.load(5)
	end

	if self.data.back == nil then
		self.data.back = backNavigation.new(L"menu:changeUnits", leave)
	end

	if self.data.applyButton == nil then
		self.data.applyButton = imageButton.new("assets/image/ui/com_button_14")
		self.data.applyButton:addEventListener("released", function()
			local tval = {}
			for i = 9, 1, -1 do
				tval[#tval + 1] = self.persist.unitList[i]
				self.persist.currentUnitList[i] = self.persist.unitList[i]
			end

			setting.set("IDOL_IMAGE", table.concat(tval, "\t"))
		end)
	end

	if self.data.cancelButton == nil then
		self.data.cancelButton = imageButton.new("assets/image/ui/com_button_15")
		self.data.cancelButton:addEventListener("released", function()
			for i = 1, 9 do
				self.persist.unitList[i] = self.persist.currentUnitList[i]
			end
		end)
	end

	if self.data.unitImageList == nil then
		self.data.unitImageList = setmetatable({}, {
			__index = function()
				return self.assets.images.dummyUnit
			end
		})

		-- scan directory
		local unitLoad = {}
		local unitFilename = {}
		for _, file in ipairs(love.filesystem.getDirectoryItems("unit_icon")) do
			local path = "unit_icon/"..file
			if file:sub(-4) == ".png" and util.fileExists(path) then
				unitLoad[#unitLoad + 1] = {lily.newImage, path, mipmap}
				unitFilename[#unitFilename + 1] = file
			end
		end

		-- load (cannot use assetCache because assetCache caches the image)
		local unitImage = lily.loadMulti(unitLoad)
		while unitImage:isComplete() == false do
			async.wait()
		end
		for i = 1, #unitFilename do
			self.data.unitImageList[unitFilename[i]] = unitImage:getValues(i)
		end
	end
end

function changeUnits:start()
	self.persist.currentUnitList = {}
	self.persist.unitList = {}
	self.persist.currentKeymap = {}
	self.persist.keymap = {}

	-- load unit image name
	do
		local i = 9
		for w in setting.get("IDOL_IMAGE"):gmatch("[^\t]+") do
			self.persist.unitList[i] = w
			self.persist.currentUnitList[i] = w
			i = i - 1
		end

		assert(i == 0, "improper idol image setting")
	end

	-- load keymap
	do
		local i = 9
		for w in setting.get("IDOL_KEYS"):gmatch("[^\t]+") do
			self.persist.keymap[i] = w
			self.persist.currentKeymap[i] = w
			i = i - 1
		end

		assert(i == 0, "improper keymap setting")
	end
end

function changeUnits:draw()
	love.graphics.setColor(color.white)
	love.graphics.draw(self.data.background)
	love.graphics.draw(self.data.changeUnitText)

	for i = 1, 9 do
		love.graphics.draw(
			self.data.unitImageList[self.persist.unitList[i]],
			idolPosition[i][1], idolPosition[i][2], 0, 1, 1, 64, 64
		)
	end

	-- keymap test
	love.graphics.setColor(color.orangeRed)
	for i = 1, 9 do
		if love.keyboard.isDown(self.persist.keymap[i]) then
			love.graphics.draw(
				self.assets.images.dummyUnit,
				idolPosition[i][1], idolPosition[i][2], 0, 1, 1, 64, 64
			)
		end
	end

	backNavigation.draw(self.data.back)
	gui.draw()
end

changeUnits:registerEvent("keyreleased", function(_, key)
	if key == "escape" then
		return leave()
	end
end)

return changeUnits
