#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="${1:-$repo_root/dist/伺か再現プロジェクト.app}"
info_plist="$app_path/Contents/Info.plist"
executable="$app_path/Contents/MacOS/UkagakaReproductionProject"
characters="$app_path/Contents/Resources/Characters"

test -d "$app_path"
test -x "$executable"
test -f "$app_path/Contents/Resources/AppIcon.icns"
plutil -lint "$info_plist"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$info_plist")" = "jp.kyo563.ukagaka-reproduction-project"
test "$(/usr/libexec/PlistBuddy -c 'Print :LSUIElement' "$info_plist")" = "true"
test "$(find "$characters" -maxdepth 1 -type f -name '*.png' | wc -l | tr -d ' ')" -ge 8
codesign --verify --deep --strict --verbose=2 "$app_path"

if [[ "${ARCHS:-native}" == "universal" ]]; then
    lipo "$executable" -verify_arch x86_64 arm64
fi

echo "Verified: $app_path"
file "$executable"
