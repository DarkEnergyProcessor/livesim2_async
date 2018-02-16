-- LLP beatmap download
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local JSON = require("JSON")
local love = love
local BackgroundImage = AquaShine.LoadModule("uielement.background_image")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BackNavigation = AquaShine.LoadModule("uielement.backnavigation")
local DLBeatmap = {Status = "Copy the LLP beatmap URL from m.tianyi9.com and open this window"}
local resplen = 0

DLBeatmap.CB = {
	Error = function(this, msg)
		DLBeatmap.Status = "Error: "..msg
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	end,
	Receive = function(this, msg)
		resplen = resplen + #msg
		DLBeatmap.Response[#DLBeatmap.Response + 1] = msg
	end,
	Done = function(this, msg)
		resplen = 0
		
		if this.StatusCode ~= 200 then
			DLBeatmap.Status = "Error: Unknown error"
			DLBeatmap.DLButton:enable()
			DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
		else
			local json = JSON:decode(table.concat(DLBeatmap.Response))
			DLBeatmap.Status = "Redirecting..."
			if not(DLBeatmap.Quit) then
				AquaShine.LoadEntryPoint("download_beatmap_llp2.lua", json)
			end
		end
	end
}

function DLBeatmap.Start()
	local dummycanvas = love.graphics.newCanvas(144, 58)
	local s_button_03 = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
	local s_button_03se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
	dummycanvas:renderTo(function() love.graphics.clear(0, 0, 0, 0) end)
	
	DLBeatmap.Download = AquaShine.GetCachedData("BeatmapDLHandle", AquaShine.Download)
	DLBeatmap.LiveIDFont = AquaShine.LoadFont("MTLmr3m.ttf", 24)
	DLBeatmap.DLButton = SimpleButton(dummycanvas, dummycanvas, function()
		DLBeatmap.Response = {}
		DLBeatmap.Download:Download("https://m.tianyi9.com/API/getlive?live_id="..DLBeatmap.ClipLiveID)
		DLBeatmap.DLButton:disable()
		DLBeatmap.DLButton:setTextColor(0, 0, 0, 0)
		DLBeatmap.Status = "Loading..."
	end)
		:setDisabledImage(dummycanvas)
		:setPosition(102, 180)
		:initText(DLBeatmap.LiveIDFont, "Download")
		:setTextPosition(22, 12)
	DLBeatmap.LiveIDString = ""
	DLBeatmap.MainNode = BackgroundImage(15)
		:addChild(BackNavigation("LLP Download Beatmap", ":beatmap_select"))
		:addChild(DLBeatmap.DLButton)
		:addChild(SimpleButton(s_button_03, s_button_03se, function()
				AquaShine.SaveConfig("DL_CURRENT", "download_beatmap_sif.lua")
				AquaShine.LoadEntryPoint("download_beatmap_sif.lua")
			end, 0.5)
			:setPosition(696, 18)
			:initText(AquaShine.LoadFont("MTLmr3m.ttf", 14), "SIF Download Beatmap")
			:setTextPosition(8, 8)
		)
	
	return DLBeatmap.Focus()
end

function DLBeatmap.Update(deltaT)
	if not(AquaShine.Download.HasHTTPS()) then
		-- No HTTPS? Switch to proxy mode
		local dest = "external/download_beatmap_llp.lua"
		if not(love.filesystem.getInfo(dest)) then
			dest = "download_beatmap_sif.lua"
		end
		
		AquaShine.SaveConfig("DL_CURRENT", dest)
		AquaShine.LoadEntryPoint(dest)
		return
	end
	
	if not(DLBeatmap.Download.downloading) and not(DLBeatmap.CallbackSet) then
		DLBeatmap.Download:SetCallback(DLBeatmap.CB)
		DLBeatmap.CallbackSet = true
	end
end

function DLBeatmap.Draw()
	DLBeatmap.MainNode:draw()
	love.graphics.setFont(DLBeatmap.LiveIDFont)
	love.graphics.print("HTTPS mode", 420, 10)
	love.graphics.print(DLBeatmap.LiveIDString, 102, 136)
	love.graphics.print(DLBeatmap.Status, 102, 380)
end

function DLBeatmap.Focus()
	if DLBeatmap.Download.downloading then return end
	
	DLBeatmap.ClipLiveID = love.system.getClipboardText()
	DLBeatmap.ClipLiveID = DLBeatmap.ClipLiveID:match("live_id=(%w+)") or DLBeatmap.ClipLiveID:sub(1, 18)
	DLBeatmap.ClipLiveID = DLBeatmap.ClipLiveID:find("%W+") and "" or DLBeatmap.ClipLiveID
	DLBeatmap.LiveIDString = "Live ID: "..DLBeatmap.ClipLiveID
	
	if #DLBeatmap.ClipLiveID > 0 and not(DLBeatmap.ClipLiveID:find("%W+")) then
		DLBeatmap.DLButton:enable()
		DLBeatmap.DLButton:setTextColor(1, 1, 1, 1)
	else
		DLBeatmap.DLButton:disable()
		DLBeatmap.DLButton:setTextColor(0, 0, 0, 0)
	end
end

function DLBeatmap.MousePressed(x, y, b, t)
	return DLBeatmap.MainNode:triggerEvent("MousePressed", x, y, b, t)
end

function DLBeatmap.MouseMoved(x, y, dx, dy, t)
	return DLBeatmap.MainNode:triggerEvent("MouseMoved", x, y, dx, dy, t)
end

function DLBeatmap.MouseReleased(x, y, b, t)
	return DLBeatmap.MainNode:triggerEvent("MouseReleased", x, y, b, t)
end

function DLBeatmap.Exit()
	if DLBeatmap.Download:IsDownloading() then DLBeatmap.Download:Cancel() end
	DLBeatmap.Quit = true
end

return DLBeatmap, "LLP Download Beatmap"
