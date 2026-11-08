#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."

swift build -c release
bin="$(swift build -c release --show-bin-path)"

app="build/Whisker.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$bin/Whisker" "$app/Contents/MacOS/Whisker"
cp Resources/Info.plist "$app/Contents/Info.plist"
cp -R devices "$app/Contents/Resources/Devices"

identity="${SIGN_IDENTITY:-$(security find-identity -v -p codesigning | awk -F'"' '/Apple Development|Developer ID Application/ {print $2; exit}')}"
codesign --force --sign "${identity:--}" "$app"
echo "Built $app (signed with ${identity:-ad-hoc})"
