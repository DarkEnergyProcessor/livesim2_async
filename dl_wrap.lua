-- Beatmap download wrapper
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = require("love")
local BackNavigation = AquaShine.LoadModule("uielement.backnavigation")
local DLWrap = {}

function DLWrap.Start()
	DLWrap.Delay = 10000
	DLWrap.Download = AquaShine.GetCachedData("BeatmapDLHandle", AquaShine.Download)
	DLWrap.LiveIDFont = AquaShine.LoadFont("MTLmr3m.ttf", 24)
	DLWrap.MainNode = BackNavigation("Download Beatmap", ":beatmap_select")
end

function DLWrap.Update(deltaT)
	DLWrap.Delay = DLWrap.Delay - deltaT
	if not(DLWrap.Download:IsDownloading()) then
		AquaShine.LoadEntryPoint("download_beatmap_sif.lua")
	end

	if DLWrap.Delay <= 0 then
		DLWrap.Delay = math.huge
		DLWrap.Download:Cancel()
	end
end

function DLWrap.Draw()
	DLWrap.MainNode:draw()
	love.graphics.setFont(DLWrap.LiveIDFont)
	love.graphics.print("Please wait...", 102, 136)
end

function DLWrap.MousePressed(x, y, b, t)
	return DLWrap.MainNode:triggerEvent("MousePressed", x, y, b, t)
end

function DLWrap.MouseMoved(x, y, dx, dy, t)
	return DLWrap.MainNode:triggerEvent("MouseMoved", x, y, dx, dy, t)
end

function DLWrap.MouseReleased(x, y, b, t)
	return DLWrap.MainNode:triggerEvent("MouseReleased", x, y, b, t)
end

return DLWrap
