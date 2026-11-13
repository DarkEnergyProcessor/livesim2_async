#!/bin/bash
# Makes the LOVE iOS app adopt the UIKit scene life cycle.
#
# Apps built with the iOS 27 SDK (Xcode 27) are killed at launch unless they
# declare a scene manifest (EXC_BREAKPOINT in
# __UIApplicationEvaluateRuntimeIssueForNoSceneLifecycleAdoption). LOVE 11.5
# and its bundled SDL2 predate that rule, so this script:
#   1. appends a small scene delegate to LOVE's src/common/ios.mm that hands
#      SDL's window to the connected scene, and
#   2. adds UIApplicationSceneManifest to the app's Info.plist.
# It is safe to run more than once.
#
# Usage: bash tools/ios/adopt_uiscene.sh [path to love-11.5-ios-source]
#   default: ~/livesim-ios/love-11.5-ios-source
set -euo pipefail

SRC="${1:-$HOME/livesim-ios/love-11.5-ios-source}"
IOSMM="$SRC/src/common/ios.mm"
PLIST="$SRC/platform/xcode/ios/love-ios.plist"
MARK="LOVE_UISCENE_ADOPTION"

[ -f "$IOSMM" ] || { echo "Not found: $IOSMM"; exit 1; }
[ -f "$PLIST" ] || { echo "Not found: $PLIST"; exit 1; }

# 1. Scene delegate + window attachment ---------------------------------------
if grep -q "$MARK" "$IOSMM"; then
	echo "ios.mm already patched"
else
	cat >> "$IOSMM" <<'EOF'

// ---- LOVE_UISCENE_ADOPTION ---------------------------------------------------
// Scene life cycle support, required for apps built with the iOS 27 SDK.
// SDL2 still creates its UIWindow the old way (initWithFrame:), and a window
// without a window scene never reaches the screen, so every window that is
// made key and visible is attached to the app's scene, whichever comes first.
// SDL takes its pause/resume events from UIApplication notifications, which
// UIKit keeps posting under the scene life cycle, so nothing is forwarded.
#ifdef LOVE_IOS

#import <objc/runtime.h>

static NSHashTable *loveSceneWindows = nil;   // weak: every window shown so far
static NSHashTable *loveSceneKeyWindow = nil; // weak: the last window made key
static UIWindowScene *loveWindowScene = nil;

static void loveAttachWindowToScene(UIWindow *window)
{
	if (@available(iOS 13.0, *))
	{
		if (loveWindowScene != nil && window.windowScene == nil)
			window.windowScene = loveWindowScene;
	}
}

@interface UIWindow (LoveSceneAttach)
@end

@implementation UIWindow (LoveSceneAttach)

+ (void)load
{
	static dispatch_once_t once;
	dispatch_once(&once, ^{
		Method original = class_getInstanceMethod([UIWindow class], @selector(makeKeyAndVisible));
		Method replacement = class_getInstanceMethod([UIWindow class], @selector(love_makeKeyAndVisible));
		if (original && replacement)
			method_exchangeImplementations(original, replacement);
	});
}

- (void)love_makeKeyAndVisible
{
	if (loveSceneWindows == nil)
	{
		loveSceneWindows = [NSHashTable weakObjectsHashTable];
		loveSceneKeyWindow = [NSHashTable weakObjectsHashTable];
	}
	[loveSceneWindows addObject:self];
	[loveSceneKeyWindow removeAllObjects];
	[loveSceneKeyWindow addObject:self];
	loveAttachWindowToScene(self);
	[self love_makeKeyAndVisible]; // calls the original makeKeyAndVisible
}

@end

@interface LoveSceneDelegate : UIResponder <UIWindowSceneDelegate>
@property (nonatomic, strong) UIWindow *window;
@end

@implementation LoveSceneDelegate

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
	if (![scene isKindOfClass:[UIWindowScene class]])
		return;

	loveWindowScene = (UIWindowScene *) scene;

	// Windows SDL created before the scene connected
	for (UIWindow *window in [loveSceneWindows allObjects])
		loveAttachWindowToScene(window);

	UIWindow *keyWindow = [loveSceneKeyWindow anyObject];
	if (keyWindow != nil && !keyWindow.hidden)
		[keyWindow makeKeyAndVisible];
}

@end

#endif // LOVE_IOS
// ---- end LOVE_UISCENE_ADOPTION -----------------------------------------------
EOF
	echo "Patched $IOSMM"
fi

# 2. Scene manifest in Info.plist ---------------------------------------------
PB=/usr/libexec/PlistBuddy
if [ -x "$PB" ]; then
	if "$PB" -c "Print :UIApplicationSceneManifest" "$PLIST" >/dev/null 2>&1; then
		echo "Info.plist already has a scene manifest"
	else
		M=":UIApplicationSceneManifest"
		C="$M:UISceneConfigurations:UIWindowSceneSessionRoleApplication"
		"$PB" -c "Add $M dict" \
		      -c "Add $M:UIApplicationSupportsMultipleScenes bool false" \
		      -c "Add $M:UISceneConfigurations dict" \
		      -c "Add $C array" \
		      -c "Add $C:0 dict" \
		      -c "Add $C:0:UISceneConfigurationName string Default" \
		      -c "Add $C:0:UISceneDelegateClassName string LoveSceneDelegate" \
		      "$PLIST"
		echo "Added scene manifest to $PLIST"
	fi
else
	python3 - "$PLIST" <<'EOF'
import plistlib, sys
p = sys.argv[1]
with open(p, "rb") as f:
    d = plistlib.load(f)
if "UIApplicationSceneManifest" in d:
    print("Info.plist already has a scene manifest")
else:
    d["UIApplicationSceneManifest"] = {
        "UIApplicationSupportsMultipleScenes": False,
        "UISceneConfigurations": {
            "UIWindowSceneSessionRoleApplication": [{
                "UISceneConfigurationName": "Default",
                "UISceneDelegateClassName": "LoveSceneDelegate",
            }]
        },
    }
    with open(p, "wb") as f:
        plistlib.dump(d, f)
    print("Added scene manifest to " + p)
EOF
fi

# 3. Old deployment targets in the library project upset newer Xcode ----------
LIBPBX="$SRC/platform/xcode/liblove.xcodeproj/project.pbxproj"
if [ -f "$LIBPBX" ] && grep -q "IPHONEOS_DEPLOYMENT_TARGET = 8.0;" "$LIBPBX"; then
	sed -i.bak 's/IPHONEOS_DEPLOYMENT_TARGET = 8.0;/IPHONEOS_DEPLOYMENT_TARGET = 15.0;/g' "$LIBPBX"
	rm -f "$LIBPBX.bak"
fi

echo
echo "Done. In Xcode: Product > Clean Build Folder, then press Run."
