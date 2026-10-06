#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
render_dir="$(mktemp -d "${TMPDIR:-/tmp}/youjustsay-render.XXXXXX")"
trap 'rm -rf "$render_dir"' EXIT
swiftc -module-cache-path "$render_dir/cache" \
  Sources/YouJustSay/Models/Language.swift \
  Sources/YouJustSay/Models/AudioWaveform.swift \
  Sources/YouJustSay/Views/FloatingBarSurface.swift \
  Sources/YouJustSay/Views/DictationBar.swift \
  script/website/RenderBars.swift -o "$render_dir/render-bars"
"$render_dir/render-bars" "$PWD/website/assets/bars"
