#!/usr/bin/env bash
set -euo pipefail
MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
APP_NAME="YouJustSay"
BUNDLE_ID="app.youjustsay.native"
FINAL_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
mkdir -p "$ROOT_DIR/dist"
STAGING_DIR="$(mktemp -d "$ROOT_DIR/dist/.build-XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
APP_BUNDLE="$STAGING_DIR/$APP_NAME.app"
case "$MODE" in run|--build|--release|--debug|--logs|--telemetry|--verify) ;; *) echo "Usage: $0 [--build|--release|--debug|--logs|--telemetry|--verify]"; exit 2;; esac
if [ "$MODE" != "--build" ] && [ "$MODE" != "--release" ]; then pkill -x "$APP_NAME" >/dev/null 2>&1 || true; fi
CONFIGURATION="debug"
if [ "$MODE" = "--release" ]; then CONFIGURATION="release"; fi
swift build -c "$CONFIGURATION"
BUILD_BINARY="$(swift build -c "$CONFIGURATION" --show-bin-path)/$APP_NAME"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BUILD_BINARY" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"
cp Resources/Info.plist "$APP_BUNDLE/Contents/Info.plist"
cp -R Resources/*.lproj "$APP_BUNDLE/Contents/Resources/"
cp -R "$(dirname "$BUILD_BINARY")/YouJustSay_YouJustSay.bundle" "$APP_BUNDLE/Contents/Resources/"
mkdir -p "$APP_BUNDLE/Contents/Frameworks"
SPARKLE_FRAMEWORK="$ROOT_DIR/.build/artifacts/sparkle/Sparkle/Sparkle.xcframework/macos-arm64_x86_64/Sparkle.framework"
ditto "$SPARKLE_FRAMEWORK" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"
ICON_OUTPUT="$STAGING_DIR/icon-output"
mkdir -p "$ICON_OUTPUT"
xcrun actool "$ROOT_DIR/Resources/AppIcon.icon" --compile "$ICON_OUTPUT" --platform macosx --minimum-deployment-target 14.0 --app-icon AppIcon --output-partial-info-plist "$ROOT_DIR/.build/icon-info.plist" --output-format human-readable-text
cp "$ICON_OUTPUT/AppIcon.icns" "$ICON_OUTPUT/Assets.car" "$APP_BUNDLE/Contents/Resources/"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconFile string AppIcon' "$APP_BUNDLE/Contents/Info.plist"
/usr/libexec/PlistBuddy -c 'Add :CFBundleIconName string AppIcon' "$APP_BUNDLE/Contents/Info.plist"
SIGNING_IDENTITY="${YOUJUSTSAY_SIGNING_IDENTITY:--}"
# Sign nested executables from the inside out; preserve Sparkle's helper structure.
SPARKLE_VERSION="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B"
for COMPONENT in "$SPARKLE_VERSION"/XPCServices/*.xpc "$SPARKLE_VERSION/Updater.app" "$SPARKLE_VERSION/Autoupdate" "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"; do
    codesign --force --preserve-metadata=entitlements --sign "$SIGNING_IDENTITY" "$COMPONENT"
done
codesign --force --sign "$SIGNING_IDENTITY" "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"
if [ -d "$FINAL_BUNDLE" ]; then mv "$FINAL_BUNDLE" "$STAGING_DIR/previous.app"; fi
mv "$APP_BUNDLE" "$FINAL_BUNDLE"
APP_BUNDLE="$FINAL_BUNDLE"
case "$MODE" in
 --build|--release) ;;
 --debug) lldb -- "$APP_BUNDLE/Contents/MacOS/$APP_NAME" ;;
 --logs) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'process == "YouJustSay"' ;;
 --telemetry) open -n "$APP_BUNDLE"; /usr/bin/log stream --info --style compact --predicate 'subsystem == "app.youjustsay.native"' ;;
 --verify) open -n "$APP_BUNDLE"; sleep 2; pgrep -x "$APP_NAME" >/dev/null; echo 'Launch verified' ;;
 run) open -n "$APP_BUNDLE" ;;
esac
