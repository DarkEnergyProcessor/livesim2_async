-- Live header
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local love = require("love")
local DEPLS, AquaShine = ...
local LiveHeader = {}

local function init()
	-- Load live header images
	LiveHeader.Header = AquaShine.LoadImage("assets/image/live/live_header.png")
	LiveHeader.ScoreGauge = AquaShine.LoadImage("assets/image/live/live_gauge_03_02.png")
	LiveHeader.Pause = AquaShine.LoadImage("assets/image/live/live_pause.png")

	return LiveHeader
end

function LiveHeader.Update()
	if not(LiveHeader.Init2) then
		local stamina_display_str = tostring(DEPLS.Stamina)
		local matcher = stamina_display_str:gmatch("%d")
		local temp
		local temp_num
		local stamina_number_image = {}
		local stamina_num = {}

		for i = 1, #stamina_display_str do
			temp = matcher()
			temp_num = tonumber(temp)

			if stamina_num[temp_num] == nil then
				stamina_num[temp_num] = AquaShine.LoadImage("assets/image/live/hp_num/live_num_"..temp..".png")
			end

			stamina_number_image[i] = stamina_num[temp_num]
		end

		LiveHeader.StaminaDrawTarget = stamina_number_image
		LiveHeader.StaminaBar = AquaShine.LoadImage("assets/image/live/live_gauge_02_02.png")
		LiveHeader.Init2 = true
	end
end

function LiveHeader.DrawPause()
	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
	love.graphics.draw(LiveHeader.Pause, 916, 5, 0, 0.6)
end

function LiveHeader.Draw()
	-- Live header
	love.graphics.setColor(1, 1, 1, DEPLS.LiveOpacity)
	love.graphics.draw(LiveHeader.Header, 0, 0)
	love.graphics.draw(LiveHeader.ScoreGauge, 5, 8, 0, 0.99545454, 0.86842105)

	-- Stamina
	love.graphics.draw(LiveHeader.StaminaBar, 14, 60)
	for i = 1, #LiveHeader.StaminaDrawTarget do
		love.graphics.draw(LiveHeader.StaminaDrawTarget[i], 290 + 16 * i, 66)
	end
end

return init()
