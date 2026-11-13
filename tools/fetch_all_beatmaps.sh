#!/bin/bash
# Downloads every song plus the chosen difficulties into the game's save folder.
#
# Usage: bash tools/fetch_all_beatmaps.sh [DIFFS]
#   DIFFS: comma list, default EXPERT,MASTER
#   (others: EASY, NORMAL, HARD, SIFAC)
# Re-running only fetches what's missing.
set -euo pipefail
REPO="$(cd "$(dirname "$0")/.." && pwd)"
LOVE="${LOVE:-}"
for c in "$HOME/Applications/love.app/Contents/MacOS/love" "/Applications/love.app/Contents/MacOS/love" "$(command -v love || true)"; do
	[ -n "$LOVE" ] && break
	[ -x "$c" ] && LOVE="$c"
done
[ -n "$LOVE" ] || { echo "LOVE not found. Set LOVE=/path/to/love"; exit 1; }
exec "$LOVE" "$REPO/tools/fetch_all_beatmaps" "${SAVE_DIR:-$HOME/Library/Application Support/LOVE/DEPLS}" "${1:-EXPERT,MASTER}"
