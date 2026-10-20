#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
NOTARY_PROFILE="${YOUJUSTSAY_NOTARY_PROFILE:-}"
USE_NOTARIZED_APP="${YOUJUSTSAY_USE_NOTARIZED_APP:-0}"
if [ "$USE_NOTARIZED_APP" != 0 ] && [ "$USE_NOTARIZED_APP" != 1 ]; then
    echo 'YOUJUSTSAY_USE_NOTARIZED_APP must be 0 or 1.' >&2
    exit 1
fi
if [ "$USE_NOTARIZED_APP" = 1 ] && [ -n "$NOTARY_PROFILE" ]; then
    echo 'Use either an existing notarized app or a notary profile, not both.' >&2
    exit 1
fi
if [ -n "$NOTARY_PROFILE" ] || [ "$USE_NOTARIZED_APP" = 1 ]; then
    if [ -z "${YOUJUSTSAY_SIGNING_IDENTITY:-}" ] || [ "$YOUJUSTSAY_SIGNING_IDENTITY" = "-" ]; then
        echo 'Notarization requires YOUJUSTSAY_SIGNING_IDENTITY (Developer ID Application).' >&2
        exit 1
    fi
    if ! security find-identity -v -p codesigning | grep -F 'Developer ID Application:' | grep -F -- "$YOUJUSTSAY_SIGNING_IDENTITY" >/dev/null; then
        echo 'The selected identity is not a valid Developer ID Application identity.' >&2
        exit 1
    fi
fi
if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null
fi
if [ "$USE_NOTARIZED_APP" = 1 ]; then
    # Xcode Organizer can notarize with an already signed-in Apple account.
    # Never rebuild or re-sign an app after its notarization ticket is issued.
    codesign --verify --deep --strict dist/YouJustSay.app
    xcrun stapler validate dist/YouJustSay.app
    spctl --assess --type execute --verbose=2 dist/YouJustSay.app
    for VERSION_KEY in CFBundleShortVersionString CFBundleVersion; do
        if [ "$(/usr/libexec/PlistBuddy -c "Print :$VERSION_KEY" Resources/Info.plist)" != "$(/usr/libexec/PlistBuddy -c "Print :$VERSION_KEY" dist/YouJustSay.app/Contents/Info.plist)" ]; then
            echo "The notarized app does not match the source $VERSION_KEY; export the current archive first." >&2
            exit 1
        fi
    done
else
    ./script/build_and_run.sh --release
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/YouJustSay.app/Contents/Info.plist)
ARCH=$(uname -m)
NAME="YouJustSay-${VERSION}-macOS-${ARCH}"
if [ "$ARCH" != "arm64" ]; then
    echo 'The current GitHub update feed distributes arm64 builds only.' >&2
    exit 1
fi
STAGING_DIR=$(mktemp -d "$ROOT_DIR/dist/.package-XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
if [ -n "$NOTARY_PROFILE" ]; then
    ditto -c -k --keepParent dist/YouJustSay.app "$STAGING_DIR/notarization.zip"
    xcrun notarytool submit "$STAGING_DIR/notarization.zip" --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist > "dist/$NAME-app-notarization.plist"
    if [ "$(/usr/libexec/PlistBuddy -c 'Print :status' "dist/$NAME-app-notarization.plist")" != 'Accepted' ]; then
        echo 'App notarization was not accepted; see the notarization result in dist.' >&2
        exit 1
    fi
    xcrun stapler staple dist/YouJustSay.app
    xcrun stapler validate dist/YouJustSay.app
    spctl --assess --type execute --verbose=2 dist/YouJustSay.app
    rm "$STAGING_DIR/notarization.zip"
fi
cp -R dist/YouJustSay.app "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cp docs/INSTALL-LOCAL.zh-CN.md "$STAGING_DIR/安装说明.txt"
if [ -n "$NOTARY_PROFILE" ] || [ "$USE_NOTARIZED_APP" = 1 ]; then
    cp docs/INSTALL-NOTARIZED.zh-CN.md "$STAGING_DIR/安装说明.txt"
fi
hdiutil create -volname "YouJustSay $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "dist/$NAME.dmg"
if [ -n "$NOTARY_PROFILE" ] || [ "$USE_NOTARIZED_APP" = 1 ]; then
    codesign --force --timestamp --sign "$YOUJUSTSAY_SIGNING_IDENTITY" "dist/$NAME.dmg"
    codesign --verify --strict "dist/$NAME.dmg"
fi
if [ -n "$NOTARY_PROFILE" ]; then
    xcrun notarytool submit "dist/$NAME.dmg" --keychain-profile "$NOTARY_PROFILE" --wait --output-format plist > "dist/$NAME-dmg-notarization.plist"
    if [ "$(/usr/libexec/PlistBuddy -c 'Print :status' "dist/$NAME-dmg-notarization.plist")" != 'Accepted' ]; then
        echo 'DMG notarization was not accepted; see the notarization result in dist.' >&2
        exit 1
    fi
    xcrun stapler staple "dist/$NAME.dmg"
    xcrun stapler validate "dist/$NAME.dmg"
    codesign --verify --strict "dist/$NAME.dmg"
    spctl --assess --type open --context context:primary-signature --verbose=2 "dist/$NAME.dmg"
fi
UPDATE_DIR="$STAGING_DIR/updates"
mkdir -p "$UPDATE_DIR"
cp "dist/$NAME.dmg" "$UPDATE_DIR/"
"$ROOT_DIR/.build/artifacts/sparkle/Sparkle/bin/generate_appcast" \
    --account app.youjustsay.native \
    --download-url-prefix "https://github.com/nufegia/YouJustSay/releases/download/v$VERSION/" \
    --link 'https://github.com/nufegia/YouJustSay/releases/latest' \
    --maximum-deltas 0 "$UPDATE_DIR"
cp "$UPDATE_DIR/appcast.xml" dist/appcast.xml
(cd dist && shasum -a 256 "$NAME.dmg" > SHA256SUMS.txt)
echo "Release artifacts ready in dist/"
