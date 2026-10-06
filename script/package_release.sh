#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
./script/build_and_run.sh --release
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/YouJustSay.app/Contents/Info.plist)
ARCH=$(uname -m)
NAME="YouJustSay-${VERSION}-macOS-${ARCH}"
if [ "$ARCH" != "arm64" ]; then
    echo 'The current GitHub update feed distributes arm64 builds only.' >&2
    exit 1
fi
STAGING_DIR=$(mktemp -d "$ROOT_DIR/dist/.package-XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R dist/YouJustSay.app "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cp docs/INSTALL.zh-CN.md "$STAGING_DIR/安装说明.txt"
hdiutil create -volname "YouJustSay $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "dist/$NAME.dmg"
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
