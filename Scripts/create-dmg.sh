#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
version="${VERSION:-0.1.1}"
app_path="${1:-$repo_root/dist/伺か再現プロジェクト.app}"
output_path="${2:-$repo_root/dist/Ukagaka-Reproduction-Project-macOS-$version.dmg}"

if [[ ! -d "$app_path" ]]; then
    echo "App bundle not found: $app_path" >&2
    exit 66
fi

staging_dir="$(mktemp -d "${TMPDIR:-/tmp}/ukagaka-dmg.XXXXXX")"
trap 'rm -rf "$staging_dir"' EXIT
ditto "$app_path" "$staging_dir/伺か再現プロジェクト.app"
ln -s /Applications "$staging_dir/Applications"

if [[ -e "$output_path" ]]; then
    rm -f "$output_path"
fi
hdiutil create \
    -volname "伺か再現プロジェクト" \
    -srcfolder "$staging_dir" \
    -format UDZO \
    -ov \
    "$output_path" >/dev/null

echo "DMG: $output_path"
