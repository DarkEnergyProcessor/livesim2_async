-- Live Simulator: 2 Settings
-- Original written by RayFirefist, refactored by AuahDark
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

local AquaShine = ...
local love = require("love")
local TapSound = require("tap_sound")
local BackgroundLoader = AquaShine.LoadModule("background_loader")
local Settings = {
	BackImage = AquaShine.LoadImage("assets/image/ui/com_win_02.png"),
	BackButton = AquaShine.LoadImage("assets/image/ui/com_button_01.png"),
	BackButtonSe = AquaShine.LoadImage("assets/image/ui/com_button_01se.png"),

	FontConfig = AquaShine.LoadFont("MTLmr3m.ttf", 30),
	FontDesc = AquaShine.LoadFont("MTLmr3m.ttf", 22),
	DescImage = AquaShine.LoadImage("assets/image/ui/com_win_42.png"),
}
local defaultJIT = (love._os == "Android" or love._os == "iOS") and "off" or "on"

local SettingSelection = {
	{
		Name = "NOTE_STYLE", Default = 1,
		Caption = "Note Style",
		Description = [[
Set the Live Simulator: 2 note style
1. Default, original SIF note style
2. Neon note style
3. Matte note style]],
		Type = "number",
		Min = 1,
		Max = 3
	},
	{
		Name = "CBF_UNIT_LOAD", Default = 1,
		Caption = "Load CBF Units",
		Description = [[
Load Custom Beatmap Festival units or always use
units from Live Simulator: 2]],
		Type = "switch",
		On = 1,
		Off = 0
	},
	{
		Name = "MINIMAL_EFFECT", Default = 0,
		Caption = "Minimal Effect",
		Description = [[
Reduces visual effect. Enable if you experience
low framerate or stutter.]],
		Type = "switch",
		On = 1,
		Off = 0
	},
	{
		Name = "BACKGROUND_IMAGE", Default = 11,
		Caption = "Background Number",
		Description = [[
Default background to be used as fallback.

This setting menu background selects the
background based on this value, so you can see
the changes immediately.]],
		Type = "number",
		Min = 1,
		Max = 15,
		Changed = function(this)
			-- When initialized, second argument is nil
			Settings.Background = BackgroundLoader.Load(this.Value)
		end
	},
	{
		Name = "NOTE_SPEED", Default = 800,
		Caption = "Note Speed (ms)",
		Description = [[
Set the note travel speed. Quick rule of thumb:
* 700  - SIF default master speed
* 800  - SIF default expert speed
* 1000 - SIF default hard speed
* 1300 - SIF default normal speed
* 1600 - SIF default easy speed]],
		Type = "number",
		Min = 400,
		Max = 4500,
		Increment = 100
	},
	{
		Name = "LLP_SIFT_DEFATTR", Default = 10,
		Caption = "Def. Note Attribute",
		Type = "number",
		Min = 1,
		Max = 11
	},
	{
		Name = "JIT_COMPILER", Default = defaultJIT,
		Caption = "JIT (Needs Restart)",
		Description = [[
Set Lua Just-In-Time compiler.

In desktop, this is on by default, and in
mobile, this is off by default.

There's no reason to alter this setting
unless you experience frame stutter.

For ARM64 users: Always set this off!]],
		Type = "switch",
		On = "on",
		Off = "off"
	},
	{
		Name = "NS_ACCUMULATION", Default = 0,
		Caption = "N.S. Accumulation",
		Type = "switch",
		On = 1,
		Off = 0
	},
	------------------
	-- Another page --
	------------------
	{
		Name = "AUTO_BACKGROUND", Default = 1,
		Caption = "Custom Background",
		Type = "switch",
		On = 1,
		Off = 0
	},
	{
		Name = "GLOBAL_OFFSET", Default = 0,
		Caption = "Beatmap Offset",
		Type = "number",
		Min = -5000,
		Max = 5000,
		Increment = 10
	},
	{
		Name = "TEXT_SCALING", Default = 1,
		Caption = "Text Scaling",
		Type = "number",
		Min = 0.5,
		Max = 1,
		Increment = 0.1
	},
	{
		Name = "TAP_SOUND", Default = TapSound.Default,
		Caption = "SE ID",
		Type = "number",
		Min = 1,
		Max = #TapSound
	},
	{
		Name = "SE_VOLUME", Default = 80,
		Caption = "SE Volume",
		Type = "number",
		Min = 0,
		Max = 100,
		Increment = 10
	},
	{
		Name = "BEATMAP_SELECT_CACHED", Default = 0,
		Caption = "Fast Beatmap List",
		Type = "switch",
		On = 1,
		Off = 0
	},
	{
		Name = "PLAY_UI", Default = "sif",
		Caption = "Lovewing UI",
		Type = "switch",
		On = "lovewing",
		Off = "sif"
	},
	{
		Name = "AUDIO_LOWMEM", Default = 0,
		Caption = "Low Memory Audio",
		Description = [[
Enable stream audio system.

This option reduces the memory usage when
enabled, by streaming the beatmap audio
in-memory or in hard drive, and not loading
the decoded audio in memory.

Enabling this setting can introduces
additional audio-beatmap synchronization
problems which can't be fixed by pausing
and resuming the live simulator.]],
		Type = "switch",
		On = 1,
		Off = 0
	}
}

local MouseState = {0, 0, false}	-- x, y, is click?

local plus = AquaShine.LoadImage("assets/image/ui/com_etc_204.png")
local minus = AquaShine.LoadImage("assets/image/ui/com_etc_205.png")

local set_button_19 = AquaShine.LoadImage("assets/image/ui/set_button_19.png")
local set_button_19se = AquaShine.LoadImage("assets/image/ui/set_button_19se.png")

local com_button_68 = AquaShine.LoadImage("assets/image/ui/com_button_68.png")
local com_button_68se = AquaShine.LoadImage("assets/image/ui/com_button_68se.png")

local OnButton = AquaShine.LoadImage("assets/image/ui/set_button_14.png")
local OnButtonSe = AquaShine.LoadImage("assets/image/ui/set_button_14se.png")
local OffButton = AquaShine.LoadImage("assets/image/ui/set_button_15.png")
local OffButtonSe = AquaShine.LoadImage("assets/image/ui/set_button_15se.png")

local settings_index_multipler = 0

-- Usual configuration settings
function Settings.Start()
	for i = 1, #SettingSelection do
		local idx = SettingSelection[i]

		idx.Value = AquaShine.LoadConfig(idx.Name, idx.Default)

		if idx.Changed then
			idx:Changed()
		end
	end
end

function Settings.Update() end

function Settings.Draw()
	local descText

	-- Draw background
	love.graphics.draw(Settings.Background)

	-- Draw back button and image
	love.graphics.draw(Settings.BackImage, -98, 0)

	if MouseState[3] then
		if
			MouseState[1] >= 0 and MouseState[1] <= 86 and
			MouseState[2] >= 0 and MouseState[2] <= 58
		then
			love.graphics.draw(Settings.BackButtonSe)
		else
			love.graphics.draw(Settings.BackButton)
		end

		if
			MouseState[1] >= 800 and MouseState[2] >= 540 and
			MouseState[1] < 944 and MouseState[2] < 598
		then
			love.graphics.draw(set_button_19se, 800, 540)
		else
			love.graphics.draw(set_button_19, 800, 540)
		end

		if
			MouseState[1] >= 874 and MouseState[2] >= 0 and
			MouseState[1] < 960 and MouseState[2] < 58
		then
			love.graphics.draw(com_button_68se, 874, 0)
		else
			love.graphics.draw(com_button_68, 874, 0)
		end
	else
		love.graphics.draw(Settings.BackButton)
		love.graphics.draw(set_button_19, 800, 540)
		love.graphics.draw(com_button_68, 874, 0)
	end

	-- Draw label
	love.graphics.setFont(Settings.FontDesc)
	love.graphics.setColor(0, 0, 0)
	love.graphics.print("Settings", 95, 13)
	love.graphics.setColor(1, 1, 1)

	for i = settings_index_multipler * 8 + 1, (settings_index_multipler + 1) * 8 do
		local idx = SettingSelection[i]

		if idx then
			local yp = (i - settings_index_multipler * 8) * 72

			love.graphics.draw(Settings.BackImage, -110, yp)

			if idx.Type == "switch" then
				love.graphics.draw(idx.Value == idx.On and OnButtonSe or OnButton, 190, yp - 20)
				love.graphics.draw(idx.Value == idx.Off and OffButtonSe or OffButton, 275, yp - 20)

				love.graphics.setColor(0, 0, 0)
			elseif idx.Type == "number" then
				love.graphics.draw(minus, 240, yp + 10)
				love.graphics.draw(plus, 360, yp + 10)

				love.graphics.setColor(0, 0, 0)
				love.graphics.print(tostring(idx.Value), 300, yp + 10)
			end

			love.graphics.print(idx.Caption, 5, yp + 10)
			love.graphics.setColor(1, 1, 1)

			if
				MouseState[1] >= 0 and MouseState[2] >= yp and
				MouseState[1] < 394 and MouseState[2] < yp + 40
			then
				descText = idx.Description or "No description available"
			end
		else
			break
		end
	end

	descText = descText or "Hover setting to see it's description"
	-- Draw description
	love.graphics.setColor(0, 0, 0)
	love.graphics.print(descText, 420+1, 70+1)
	love.graphics.setColor(1, 1, 1)
	love.graphics.print(descText, 420, 70)
end

function Settings.MousePressed(x, y, button)
	if button ~= 1 then return end

	MouseState[1], MouseState[2] = x, y
	MouseState[3] = true
end

function Settings.MouseMoved(x, y)
	MouseState[1], MouseState[2] = x, y
end

function Settings.MouseReleased(x, y, button)
	if button ~= 1 then return end
	
	MouseState[1], MouseState[2] = x, y
	MouseState[3] = false
	
	if x >= 0 and x < 86 and y >= 0 and y < 58 then
		AquaShine.LoadEntryPoint(":main_menu")
	elseif x >= 800 and x < 944 and y >= 540 and y < 598 then
		for i = 1, #SettingSelection do
			local idx = SettingSelection[i]
			
			AquaShine.SaveConfig(idx.Name, idx.Value)
		end
	elseif x >= 874 and x < 960 and y >= 0 and y < 58 then
		settings_index_multipler = (settings_index_multipler + 1) % math.ceil(#SettingSelection / 8)
	else
		for i = settings_index_multipler * 8 + 1, (settings_index_multipler + 1) * 8 do
			local idx = SettingSelection[i]
			
			if idx then
				local oldval = idx.Value
				local yp = (i - settings_index_multipler * 8) * 72
				
				if idx.Type == "switch" and y >= yp - 17 and y < yp + 55 then
					if idx.Value ~= idx.Off and x >= 296 and x < 368 then
						-- Off
						idx.Value = idx.Off
						
						if idx.Changed then
							idx:Changed(oldval)
						end
					elseif idx.Value ~= idx.On and x >= 206 and x < 278 then
						-- On
						idx.Value = idx.On
						
						if idx.Changed then
							idx:Changed(oldval)
						end
					end
				elseif idx.Type == "number" and y >= yp + 4 and y < yp + 36 then
					if x >= 224 and x < 272 then
						-- Subtract
						idx.Value = math.max(idx.Value - (idx.Increment or 1), idx.Min)
						
						if idx.Changed then
							idx:Changed(oldval)
						end
					elseif x >= 364 and x < 412 then
						-- Add
						idx.Value = math.min(idx.Value + (idx.Increment or 1), idx.Max)
						
						if idx.Changed then
							idx:Changed(oldval)
						end
					end
				end
			end
		end
	end
end

function Settings.KeyReleased(key)
	if key == "escape" then
		AquaShine.LoadEntryPoint(":main_menu")
	end
end

return Settings, "Settings"
