# Makefile to zip all files and store it to ../depls2.zip
# Requires 7za

all: default

default:
	-rm ../depls2.zip
	7za a -mx=9 ../depls2.zip AquaShine assets noteloader livesim lovewing sound splash uielement flash external *.lua *.md MTLmr3m.ttf LICENSE.MTLmr3m about_screen_license ffmpeg_include_compressed
