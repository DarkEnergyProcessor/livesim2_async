#!/bin/bash
# Packages the game (plus beatmaps and songs you've downloaded on this Mac)
# into a single .love file to copy onto the iPhone.
#
# Usage: bash tools/ios/package_game.sh [output file]
#   default output: ~/livesim-ios/livesim2.love
set -euo pipefail

REPO="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${1:-$HOME/livesim-ios/livesim2.love}"
SAVE="${SAVE_DIR:-$HOME/Library/Application Support/LOVE/DEPLS}"

mkdir -p "$(dirname "$OUT")"
OUT="$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

tar -C "$REPO" --exclude=.git --exclude=docs --exclude=build-util --exclude=tools -cf - . | tar -C "$TMP" -xf -

# Bundle downloaded beatmaps + audio (the in-game downloader doesn't work on iPhone)
found=0
for d in beatmap audio live_icon cards keynotes; do
	if [ -d "$SAVE/$d" ]; then
		mkdir -p "$TMP/$d"
		cp -R "$SAVE/$d/." "$TMP/$d/"
		found=1
	fi
done
if [ "$found" = 0 ]; then
	echo "Note: no downloaded beatmaps found in $SAVE"
fi

rm -f "$OUT"
(cd "$TMP" && zip -q -r -X "$OUT" .)

echo "Built $OUT ($(du -h "$OUT" | cut -f1))"
echo "Beatmaps included: $(ls "$TMP/beatmap" 2>/dev/null | wc -l | tr -d ' ')"
