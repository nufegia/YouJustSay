#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
./script/build_and_run.sh --release
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' dist/YouJustSay.app/Contents/Info.plist)
ARCH=$(uname -m)
NAME="YouJustSay-${VERSION}-macOS-${ARCH}"
STAGING_DIR=$(mktemp -d "$ROOT_DIR/dist/.package-XXXXXX")
trap 'rm -rf "$STAGING_DIR"' EXIT
cp -R dist/YouJustSay.app "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
cp docs/INSTALL.zh-CN.md "$STAGING_DIR/安装说明.txt"
hdiutil create -volname "YouJustSay $VERSION" -srcfolder "$STAGING_DIR" -ov -format UDZO "dist/$NAME.dmg"
(cd dist && shasum -a 256 "$NAME.dmg" > SHA256SUMS.txt)
echo "Release artifacts ready in dist/"
