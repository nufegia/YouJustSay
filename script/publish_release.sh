#!/usr/bin/env bash
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"
if [ "$#" != 1 ] || [ ! -f "$1" ]; then
    echo "Usage: $0 path/to/release-notes.md (creates a GitHub release draft)" >&2
    exit 2
fi
if [ -n "$(git status --porcelain)" ]; then
    echo 'Commit source changes before creating a release draft.' >&2
    exit 1
fi
VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)
TAG="v$VERSION"
./script/package_release.sh
# A draft keeps the latest public appcast and installer available until publication.
gh release create "$TAG" \
    "dist/YouJustSay-$VERSION-macOS-arm64.dmg" dist/appcast.xml dist/SHA256SUMS.txt \
    --repo nufegia/YouJustSay --target "$(git rev-parse HEAD)" \
    --draft --title "YouJustSay · 你就说 $VERSION" --notes-file "$1"
