-- SIF Beatmap Download
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local JSON = require("JSON")
local md5 = require("md5hash")
local BackgroundImage = AquaShine.LoadModule("uielement.background_image")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BackNavigation = AquaShine.LoadModule("uielement.backnavigation")
local TextShadow = AquaShine.LoadModule("uielement.text_with_shadow")
local Address = require("download_address")
local DLBeatmap = {}

-- Set callbacks
DLBeatmap.DLCB = {
	Response = {},
	RespLen = 0,
	Error = function(_, msg)
		DLBeatmap.SetStatus("Cannot get beatmap list: "..msg)
		DLBeatmap.DLCB.Response = {}
		DLBeatmap.DLCB.RespLen = 0
	end,
	Receive = function(this, data)
		DLBeatmap.DLCB.RespLen = DLBeatmap.DLCB.RespLen + #data
		DLBeatmap.DLCB.Response[#DLBeatmap.DLCB.Response + 1] = data

		-- If ContentLength is provided, show progress as percent
		if this.ContentLength then
			DLBeatmap.SetStatus(string.format("Downloading Beatmap List... (%d%%)", DLBeatmap.DLCB.RespLen / this.ContentLength * 100))
		end
	end,
	Done = function(this)
		-- If the response code is 304, that means our previous copy is good.
		if this.StatusCode == 304 then
			DLBeatmap.SetStatus("Local copy is used")
			-- resplen will be 0 anyway
			return
		elseif this.StatusCode == 200 then
			-- Setup beatmap list, sort by live track ID
			local str = table.concat(DLBeatmap.DLCB.Response)
			local json = JSON:decode(str)
			local etag = this.HeaderData["ETag"] or this.HeaderData["etag"]
			assert(love.filesystem.write("maps.json", love.data.compress("string", "zlib", str, 9)))
			assert(love.filesystem.write("maps.json.etag", etag))
			DLBeatmap.DLCB.RespLen = 0
			DLBeatmap.DLCB.Response = {}
			DLBeatmap.SetStatus("List refreshed!")
			DLBeatmap.SetupList(json)
		else
			-- Error
			DLBeatmap.SetStatus("Cannot get beatmap list: Status code "..this.StatusCode)
		end

		DLBeatmap.DLCB.Response = {}
		DLBeatmap.DLCB.RespLen = 0
	end,
}

function DLBeatmap.CommonSelectFunc(node)
	AquaShine.LoadEntryPoint("download_beatmap_sif2.lua", {DLBeatmap.BeatmapListRaw, node.beatmapindex})
end

function DLBeatmap.SetupList(beatmaplist)
	local live_track = {}

	for _, v in ipairs(beatmaplist) do
		-- Ignore it if it's TECHNICAL difficulty
		if v.difficulty_text ~= "TECHNICAL" then
			-- According to ieb, if the `live_difficulty_id` is 20000 and later
			-- then it's SIFAC beatmap.
			if v.live_setting_id >= 20000 then
				v.difficulty_text = "SIFAC"
			end

			local trackidx
			-- Find the live track
			for i = 1, #live_track do
				if live_track[i].track == v.live_track_id then
					trackidx = live_track[i]
					break
				end
			end

			if not(trackidx) then
				trackidx = {}
				live_track[#live_track + 1] = trackidx

				trackidx.track = v.live_track_id
				trackidx.name = v.name_translations and v.name_translations.english or v.name
				trackidx.name = #trackidx.name > 0 and trackidx.name or v.name
				trackidx.song = v.sound_asset
				trackidx.icon = v.live_icon_asset
				trackidx.live = {}
				if trackidx.name:find("* ", 1, true) == 1 then
					-- Unofficial romaji, but we don't care ¯\_(ツ)_/¯
					trackidx.name = trackidx.name:sub(3)
				end
			end

			-- Create information data
			local infodata = {}
			trackidx.live[v.difficulty_text] = infodata

			-- in C, B, A, S format
			infodata.score = {}
			infodata.score[1], infodata.score[2] = v.c_rank_score, v.b_rank_score
			infodata.score[3], infodata.score[4] = v.a_rank_score, v.s_rank_score
			infodata.combo = {}
			infodata.combo[1], infodata.combo[2] = v.c_rank_combo, v.b_rank_combo
			infodata.combo[3], infodata.combo[4] = v.a_rank_combo, v.s_rank_combo

			-- Background
			infodata.background = math.min(v.stage_level, 12)
			infodata.star = v.stage_level
			if v.member_category == 2 and v.stage_level < 4 then
				infodata.background = 12 + v.stage_level
			end

			-- Livejson info
			infodata.livejson = "livejson/"..v.notes_setting_asset
		end
	end

	DLBeatmap.BeatmapListRaw = live_track

	-- Setup node
	local s_button_03 = AquaShine.LoadImage("assets/image/ui/s_button_03.png")
	local s_button_03se = AquaShine.LoadImage("assets/image/ui/s_button_03se.png")
	local selectFont = AquaShine.LoadFont("MTLmr3m.ttf", 14)
	DLBeatmap.NodePageList = {}

	for i = 1, math.ceil(#live_track / 40) do
		local nodelist = AquaShine.Node()

		for j = 1, 40 do
			local idx = (i - 1) * 40 + j
			local val = DLBeatmap.BeatmapListRaw[idx]
			if val then
				local node = SimpleButton(s_button_03, s_button_03se, DLBeatmap.CommonSelectFunc, 0.5)
					:setPosition(48 + ((j - 1) % 4) * 216, 100 + math.floor((j - 1) / 4) * 40)
					:initText(selectFont, val.name)
					:setTextPosition(8, 8)
				node.beatmapindex = idx
				nodelist:addChild(node)
			else
				break
			end
		end

		DLBeatmap.NodePageList[#DLBeatmap.NodePageList + 1] = nodelist
	end

	DLBeatmap.MainNode.brother = DLBeatmap.NodePageList[1]
	DLBeatmap.MainNode.child[2]:setText("Page 1/"..#DLBeatmap.NodePageList)
end

function DLBeatmap.SetStatus(status)
	status = status or ""
	DLBeatmap.MainNode.child[3]:setText(status)
end

function DLBeatmap.MovePage(inc)
	if not(DLBeatmap.BeatmapListRaw) then return end

	DLBeatmap.CurrentPage = DLBeatmap.CurrentPage + inc
	local idx = (DLBeatmap.CurrentPage) % #DLBeatmap.NodePageList
	DLBeatmap.CurrentPage = (idx == idx and idx or 0)
	DLBeatmap.MainNode.child[2]:setText(string.format("Page %d/%d", DLBeatmap.CurrentPage + 1, #DLBeatmap.NodePageList))
	DLBeatmap.MainNode.brother = DLBeatmap.NodePageList[DLBeatmap.CurrentPage + 1]
end

function DLBeatmap.Start()
	local maps_info = love.filesystem.getInfo("maps.json.etag")
	local descFont = AquaShine.LoadFont("MTLmr3m.ttf", 22)
	DLBeatmap.SwipeData = {nil, nil}
	DLBeatmap.SwipeThreshold = 128
	DLBeatmap.CurrentPage = 0
	DLBeatmap.Download = AquaShine.GetCachedData("BeatmapDLHandle", AquaShine.Download)
	DLBeatmap.MainNode = BackgroundImage(13)
		:addChild(BackNavigation("SIF Download Beatmap", ":beatmap_select"))
		:addChild(TextShadow(descFont, "", 52, 500)
			:setShadow(1, 1, true)
		)
		:addChild(TextShadow(descFont, "", 52, 536)
			:setShadow(1, 1, true)
		)

	-- If maps.json.etag exist, that means we downloaded a previous copy
	-- and we keep attempt to download it, but by specifying If-None-Match.
	-- In case of failure, if previous copy exist, use it anyway.
	if maps_info then
		local json = JSON:decode(love.data.decompress("string", "zlib", love.filesystem.read("maps.json")))
		DLBeatmap.LastCopy = love.filesystem.read("maps.json.etag")
		DLBeatmap.SetupList(json)
	end
end

function DLBeatmap.Update()
	if not(DLBeatmap.Download.downloading) and not(DLBeatmap.IsDownloaded) then
		local header
		if DLBeatmap.LastCopy then
			header = {["If-None-Match"] = DLBeatmap.LastCopy}
		end

		DLBeatmap.SetStatus("Downloading Beatmap List...")
		DLBeatmap.Download:SetCallback(DLBeatmap.DLCB)
		DLBeatmap.Download:Download(Address.QUERY.."/maps.json", header)
		DLBeatmap.IsDownloaded = true
	end
end

function DLBeatmap.Draw()
	return DLBeatmap.MainNode:draw()
end

function DLBeatmap.Exit()
	if DLBeatmap.Download and DLBeatmap.Download:IsDownloading() then
		DLBeatmap.Download:Cancel()
	end
end

function DLBeatmap.MousePressed(x, y, b, t)
	if not(DLBeatmap.SwipeData[1]) then
		DLBeatmap.SwipeData[1] = t or 0
		DLBeatmap.SwipeData[2] = x
	end

	return DLBeatmap.MainNode:triggerEvent("MousePressed", x, y, b, t)
end

function DLBeatmap.MouseMoved(x, y, dx, dy, t)
	DLBeatmap.MainNode:triggerEvent("MouseMoved", x, y, dx, dy, t)

	if DLBeatmap.SwipeData[1] and math.abs(DLBeatmap.SwipeData[2] - x) >= DLBeatmap.SwipeThreshold then
		DLBeatmap.MainNode:triggerEvent("MouseMoved", -200, -200, -1, -1, t)
		DLBeatmap.MainNode:triggerEvent("MouseReleased", -200, -200, 1, t)
	end
end

function DLBeatmap.MouseReleased(x, y, b, t)
	if DLBeatmap.SwipeData[1] then
		if math.abs(DLBeatmap.SwipeData[2] - x) >= DLBeatmap.SwipeThreshold then
			-- Switch page
			DLBeatmap.MovePage(DLBeatmap.SwipeData[2] - x < 0 and -1 or 1)
			DLBeatmap.SwipeData[2] = nil
		else
			DLBeatmap.MainNode:triggerEvent("MouseReleased", x, y, b, t)
		end

		DLBeatmap.SwipeData[1] = nil
	end
end

function DLBeatmap.KeyReleased(key)
	if key == "escape" then
		AquaShine.LoadEntryPoint(":beatmap_select")
	elseif key == "left" then
		DLBeatmap.MovePage(-1)
	elseif key == "right" then
		DLBeatmap.MovePage(1)
	end
end

return DLBeatmap, "SIF Download Beatmap"
