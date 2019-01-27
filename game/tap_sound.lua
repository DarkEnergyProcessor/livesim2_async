-- Tap sound definition
-- Part of Live Simulator: 2
-- See copyright notice in main.lua

return {
	-- Usual SIF tap SFX
	{
		volumeMultipler = 0.75,
		perfect = "sound/tap/sif/SE_306.ogg",
		great = "sound/tap/sif/SE_307.ogg",
		good = "sound/tap/sif/SE_308.ogg",
		bad = "sound/tap/sif/SE_309.ogg",
		starExplode = "sound/tap/sif/SE_326.ogg"
	},
	-- don't ask
	{
		volumeMultipler = 1,
		perfect = "sound/tap/gbp/00005.wav",
		great = "sound/tap/gbp/00004.wav",
		good = "sound/tap/gbp/00002.wav",
		bad = "sound/tap/gbp/00003.wav",
		starExplode = "sound/tap/sif/SE_326.ogg"
	},
	-- especially this one
	{
		volumeMultipler = 1,
		perfect = "sound/tap/gbp/a/00005.wav",
		great = "sound/tap/gbp/a/00004.wav",
		good = "sound/tap/gbp/a/00002.wav",
		bad = "sound/tap/gbp/a/00003.wav",
		starExplode = "sound/tap/sif/SE_326.ogg"
	},
	-- and even this one
	{
		volumeMultipler = 0.85,
		perfect = "sound/tap/gbp/miku/perfect.wav",
		great = "sound/tap/gbp/miku/great.wav",
		good = "sound/tap/gbp/miku/good.wav",
		bad = "sound/tap/gbp/miku/game_button.wav",
		starExplode = "sound/tap/sif/SE_326.ogg"
	}
}
