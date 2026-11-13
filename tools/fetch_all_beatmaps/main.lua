-- Bulk beatmap downloader for Live Simulator: 2
-- Downloads every song (audio + cover) and the chosen difficulties from the
-- same server the in-game downloader uses, and writes the same .ls2 files the
-- game would, straight into the game's save folder.
--
-- Run with LOVE from the repo root, e.g.
--   ~/Applications/love.app/Contents/MacOS/love tools/fetch_all_beatmaps [SAVE_DIR] [DIFFS]
-- SAVE_DIR defaults to ~/Library/Application Support/LOVE/DEPLS
-- DIFFS is a comma list, default EXPERT,MASTER

local love = require("love")

-- This tool lives in <repo>/tools/fetch_all_beatmaps; reuse the game's libraries
local src = love.filesystem.getSource()
local root = src:match("^(.*)/tools/fetch_all_beatmaps/?$")
assert(root, "run this from inside the livesim2 repo: love tools/fetch_all_beatmaps")
package.path = root.."/?.lua;"..root.."/?/init.lua;"..package.path

local JSON = require("libs.JSON")
local ls2 = require("libs.ls2")
local md5fb = require("libs.md5")

local SERVER = os.getenv("LS2_SERVER") or "https://llsifmaps.pages.dev"
local DOWNLOAD_OFFSET = -50 / 1000 -- same as the game's default DOWNLOAD_OFFSET setting

local args = love.arg.parseGameArguments(arg)
local home = os.getenv("HOME") or ""
local saveDir = args[1] or (home.."/Library/Application Support/LOVE/DEPLS")
local wantDiff = {}
for d in (args[2] or "EXPERT,MASTER"):upper():gmatch("[^,%s]+") do wantDiff[d] = true end

-- ---------------------------------------------------------------- helpers
local function md5(s) return love.data.hash("md5", s) end
local function tohex(s) return (s:gsub(".", function(c) return string.format("%02x", c:byte()) end)) end
local function basename(f) return (f:match("([^/\\]+)$")) end

-- Identical to getHashedName in game/states/download_beatmap.lua
local function getHashedName(str)
	local keyhash = tohex(md5("The quick brown fox jumps over the lazy dog"..str))
	local filehash = tohex(md5(str))
	local strb = {}
	local seed = tonumber(keyhash:sub(1, 8), 16) % 2147483648
	for _ = 1, 20 do
		local chr = math.floor(seed / 33) % 32
		local sel = chr >= 16 and keyhash or filehash
		chr = (chr % 16) + 1
		strb[#strb + 1] = sel:sub(2 * chr - 1, 2 * chr)
		seed = (214013 * seed + 2531011) % 2147483648
	end
	strb[#strb + 1] = str
	return table.concat(strb)
end

local function getLS2Name(livejson, difficulty)
	local hashedname = getHashedName(livejson)
	return hashedname:sub(1, -#livejson - 1)..".sif."..difficulty..".ls2"
end

local function shq(s) return "'"..tostring(s):gsub("'", "'\\''").."'" end
local function exists(p) local f = io.open(p, "rb") if f then f:close() return true end return false end
local function mkdir(p) os.execute("mkdir -p "..shq(p)) end
local function readFile(p) local f = assert(io.open(p, "rb")) local d = f:read("*a") f:close() return d end

local function fetch(url, dest)
	local tmp = dest..".part"
	local ok = os.execute(string.format("curl -fsSL --retry 3 --max-time 300 -o %s %s", shq(tmp), shq(url)))
	if ok == 0 or ok == true then
		os.rename(tmp, dest)
		return true
	end
	os.remove(tmp)
	return false
end

-- ---------------------------------------------------------------- main
function love.load()
	io.stdout:setvbuf("no")
	mkdir(saveDir.."/beatmap"); mkdir(saveDir.."/audio"); mkdir(saveDir.."/live_icon")
	print("Save folder: "..saveDir)
	local diffs = {} for k in pairs(wantDiff) do diffs[#diffs + 1] = k end
	table.sort(diffs)
	print("Difficulties: "..table.concat(diffs, ", "))

	local mapsPath = saveDir.."/maps.all.json"
	assert(fetch(SERVER.."/maps.json", mapsPath), "could not download maps.json")
	local mapdata = JSON:decode(readFile(mapsPath))

	-- Group by track, mirroring game/states/download_list.lua
	local tracks, byId = {}, {}
	for _, v in ipairs(mapdata) do
		if v.difficulty_text ~= "TECHNICAL" then
			if v.live_setting_id >= 20000 then v.difficulty_text = "SIFAC" end
			local t = byId[v.live_track_id]
			if not t then
				t = {name = v.name, song = v.sound_asset, icon = v.live_icon_asset, live = {}}
				if t.name:find("* ", 1, true) == 1 then t.name = t.name:sub(3) end
				byId[v.live_track_id] = t
				tracks[#tracks + 1] = t
			end
			t.live[v.difficulty_text] = {
				difficulty = v.difficulty_text,
				star = v.stage_level,
				score = {v.c_rank_score, v.b_rank_score, v.a_rank_score, v.s_rank_score},
				combo = {v.c_rank_combo, v.b_rank_combo, v.a_rank_combo, v.s_rank_combo},
				livejson = v.notes_setting_asset,
			}
		end
	end
	table.sort(tracks, function(a, b) return a.name < b.name end)

	local total, done, skipped, failed = 0, 0, 0, 0
	for _, t in ipairs(tracks) do
		for d in pairs(t.live) do if wantDiff[d] then total = total + 1 end end
	end
	print(string.format("%d songs, %d charts to fetch", #tracks, total))

	for ti, t in ipairs(tracks) do
		local wanted = {}
		for d, info in pairs(t.live) do if wantDiff[d] then wanted[#wanted + 1] = info end end
		if #wanted > 0 then
			table.sort(wanted, function(a, b) return a.difficulty < b.difficulty end)
			local audioPath = saveDir.."/audio/"..getHashedName(basename(t.song))
			local iconPath = saveDir.."/live_icon/"..getHashedName(basename(t.icon))
			local need = false
			for _, info in ipairs(wanted) do
				if not exists(saveDir.."/beatmap/"..getLS2Name(info.livejson, info.difficulty)) then need = true end
			end

			if not need then
				skipped = skipped + #wanted
			else
				print(string.format("[%d/%d] %s", ti, #tracks, t.name))
				local okAudio = exists(audioPath) or fetch(SERVER.."/"..t.song, audioPath)
				local okIcon = exists(iconPath) or fetch(SERVER.."/"..t.icon, iconPath)
				if not okAudio then
					print("   audio failed, skipping song")
					failed = failed + #wanted
				else
					local cover = okIcon and readFile(iconPath) or nil
					for _, info in ipairs(wanted) do
						local dest = saveDir.."/beatmap/"..getLS2Name(info.livejson, info.difficulty)
						if exists(dest) then
							skipped = skipped + 1
						else
							local jsonPath = dest..".json"
							if fetch(SERVER.."/"..info.livejson, jsonPath) then
								local beatmap = JSON:decode(readFile(jsonPath))
								os.remove(jsonPath)
								for i = 1, #beatmap do
									beatmap[i].timing_sec = beatmap[i].timing_sec + DOWNLOAD_OFFSET
								end
								local f = assert(io.open(dest, "wb"))
								local enc = ls2.encoder.new(f, {
									name = t.name,
									song_file = "audio/"..getHashedName(basename(t.song)),
									star = info.star,
									score = info.score,
									combo = info.combo,
								})
								:set_background_id(math.min(info.star, 12))
								:add_beatmap(beatmap)
								if cover then enc:add_cover_art({image = cover, title = t.name}) end
								enc:write()
								f:close()
								done = done + 1
								print(string.format("   %s ok (%d notes)", info.difficulty, #beatmap))
							else
								failed = failed + 1
								print("   "..info.difficulty.." download failed")
							end
						end
					end
				end
			end
		end
	end

	print(string.format("\nDone: %d new, %d already there, %d failed", done, skipped, failed))
	love.event.quit()
end

function love.draw() end
