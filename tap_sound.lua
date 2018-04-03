-- Tap sound definition
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

return {
	-- Usual SIF tap SFX
	{
		VolumeMultipler = 0.8,
		Perfect = "sound/SE_306.ogg",
		Great = "sound/SE_307.ogg",
		Good = "sound/SE_308.ogg",
		Bad = "sound/SE_309.ogg",
		StarExplode = "sound/SE_326.ogg"
	},
	-- Girls Band Party tap SFX
	{
		VolumeMultipler = 0.9,
		Perfect = "sound/time_lapse/00005.wav",
		Great = "sound/time_lapse/00004.wav",
		Good = "sound/time_lapse/00002.wav",
		Bad = "sound/time_lapse/00003.wav",
		LongHold = "sound/time_lapse/00000.wav",
		StarExplode = "sound/SE_326.ogg" -- except this :P
	},
	-- Girls Band Party tap SFX, but with Michelle remix :P
	{
		VolumeMultipler = 0.7,
		Perfect = "sound/time_lapse/michelle/00005.wav",
		Great = "sound/time_lapse/michelle/00004.wav",
		Good = "sound/time_lapse/michelle/00002.wav",
		Bad = "sound/time_lapse/michelle/00003.wav",
		LongHold = "sound/time_lapse/michelle/00000.wav",
		StarExplode = "sound/SE_326.ogg" -- As usual, this one is usual SIF
	},

	Default = 1
}
