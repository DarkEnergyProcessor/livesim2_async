#!/bin/bash
# One-time setup: downloads LOVE 11.5 for iOS, adds its libraries, and
# prepares the Xcode project so it can be signed with a free Apple ID.
#
# Usage: bash tools/ios/setup_xcode.sh [destination folder]
#   default destination: ~/livesim-ios
# Optional env vars: BUNDLE_ID (default link.shefali.sifgift), APP_NAME (default "SIF")
set -euo pipefail

DEST="${1:-$HOME/livesim-ios}"
BUNDLE_ID="${BUNDLE_ID:-link.shefali.sifgift}"
APP_NAME="${APP_NAME:-SIF}"
VER="11.5"

mkdir -p "$DEST"
cd "$DEST"

for f in "love-$VER-ios-source.zip" "love-$VER-apple-libraries.zip"; do
	if [ ! -f "$f" ]; then
		echo "Downloading $f..."
		curl -fL --progress-bar -o "$f" "https://github.com/love2d/love/releases/download/$VER/$f"
	fi
done

[ -d "love-$VER-ios-source" ] || unzip -q "love-$VER-ios-source.zip"
[ -d "love-apple-dependencies" ] || unzip -q "love-$VER-apple-libraries.zip" -x "__MACOSX/*"

XC="$DEST/love-$VER-ios-source/platform/xcode"
rm -rf "$XC/ios/libraries"
cp -R "love-apple-dependencies/iOS/libraries" "$XC/ios/libraries"

# Modern Xcode won't build for iOS 8; also give the app a unique bundle ID
# (the default org.love2d.love is already taken, so signing would fail).
PBX="$XC/love.xcodeproj/project.pbxproj"
sed -i.bak \
	-e 's/IPHONEOS_DEPLOYMENT_TARGET = 8.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' \
	-e "s/PRODUCT_BUNDLE_IDENTIFIER = org.love2d.love;/PRODUCT_BUNDLE_IDENTIFIER = $BUNDLE_ID;/g" \
	"$PBX"
rm -f "$PBX.bak"

# iOS 27 SDK requires the scene life cycle
bash "$(dirname "$0")/adopt_uiscene.sh" "$DEST/love-$VER-ios-source"

# Home-screen name
PLIST="$XC/ios/love-ios.plist"
if command -v plutil >/dev/null 2>&1; then
	plutil -replace CFBundleDisplayName -string "$APP_NAME" "$PLIST"
fi

echo
echo "Done. Xcode project:"
echo "  $XC/love.xcodeproj"
if command -v open >/dev/null 2>&1; then
	open "$XC/love.xcodeproj" || true
fi
