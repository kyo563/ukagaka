#!/bin/bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "Usage: $0 SOURCE_PNG OUTPUT_ICNS" >&2
    exit 64
fi

source_png="$1"
output_icns="$2"
iconset_dir="$(mktemp -d "${TMPDIR:-/tmp}/ukagaka-icon.XXXXXX")/AppIcon.iconset"
mkdir -p "$iconset_dir"
trap 'rm -rf "${iconset_dir%/AppIcon.iconset}"' EXIT

make_size() {
    local pixels="$1"
    local filename="$2"
    sips -s format png -z "$pixels" "$pixels" "$source_png" --out "$iconset_dir/$filename" >/dev/null
}

make_size 16 icon_16x16.png
make_size 32 icon_16x16@2x.png
make_size 32 icon_32x32.png
make_size 64 icon_32x32@2x.png
make_size 128 icon_128x128.png
make_size 256 icon_128x128@2x.png
make_size 256 icon_256x256.png
make_size 512 icon_256x256@2x.png
make_size 512 icon_512x512.png
make_size 1024 icon_512x512@2x.png

mkdir -p "$(dirname "$output_icns")"
iconutil --convert icns "$iconset_dir" --output "$output_icns"
