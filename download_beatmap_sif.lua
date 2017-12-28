-- SIF Beatmap Download
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = love
local JSON = require("JSON")
local BackgroundImage = AquaShine.LoadModule("uielement.background_image")
local SimpleButton = AquaShine.LoadModule("uielement.simple_button")
local BackNavigation = AquaShine.LoadModule("uielement.backnavigation")
local DLBeatmap = {}
local address = "http://r.llsif.win/"

-- Set callbacks
DLBeatmap.DLCB = {
	Response = {},
	RespLen = 0,
	Error = function(this, msg)
		DLBeatmap.Status = "Cannot get beatmap list: "..msg
	end,
	Receive = function(this, data)
		DLBeatmap.DLCB.RespLen = DLBeatmap.DLCB.RespLen + #data
		
		-- If ContentLength is provided, show progress as percent
		if this.ContentLength then
			DLBeatmap.Status = string.format("Downloading Beatmap List... (%d%%)", DLBeatmap.DLCB.RespLen / this.ContentLength * 100)
		end
	end,
	Done = function(this)
		-- Setup beatmap list, sort by live track ID
		local json = JSON:decode(table.concat(Response))
		DLBeatmap.SetupList(json)
	end,
}

function DLBeatmap.SetupList(beatmaplist)
	local live_track = {}
	
	for i, v in ipairs(beatmaplist) do
		local trackidx = live_track[v.live_track_id]
		
		if not(trackidx) then
			trackidx = {}
			live_track[v.live_track_id] = trackidx
			
			trackidx.name = v.name_translations and v.name_translations.english or v.name
			trackidx.song = v.sound_asset
			trackidx.icon = v.title_asset
			trackidx.live = {}
			if trackidx.name:find("* ", 1, true) == 1 then
				-- Unofficial romaji, but we don't care ¯\_(ツ)_/¯
				trackidx.name = trackidx.name:sub(3)
			end
		end
		
		-- Create information data
		local infodata = {}
		trackidx.live[v.difficulty] = infodata
		
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
	
	DLBeatmap.BeatmapListRaw = live_track
	
	-- Setup node
end

function DLBeatmap.Start(arg)
	local maps_info = love.filesystem.getInfo("maps.json")
	
	-- If there was previously cached maps data, use that
	if not(maps_info) or (maps_info.modtime or 0) + 86400 < os.time() then
		DLBeatmap.Download = AquaShine.GetCachedData("BeatmapDLHandle", AquaShine.Download)
	else
		local json = JSON:decode(love.filesystem.read("maps.json"))
		DLBeatmap.SetupList(json)
	end
end

function DLBeatmap.Update(deltaT)
	if DLBeatmap.Download and not(DLBeatmap.Download.downloading) then
		DLBeatmap.Download:SetCallback(DLBeatmap.DLCB)
		DLBeatmap.Download:Download(address.."maps.json")
	end
end

return DLBeatmap
