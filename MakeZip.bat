rem Batch script to build zip and store it to ../depls2.zip
rem Requires 7za

del ..\depls2.zip
7za a -mx=9 -x!https.lua -x!ssl.lua ../depls2.zip AquaShine assets noteloader livesim lovewing sound splash uielement flash external *.lua *.md MTLmr3m.ttf LICENSE.MTLmr3m about_screen_license ffmpeg_include_compressed