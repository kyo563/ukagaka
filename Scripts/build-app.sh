#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
product_name="伺か再現プロジェクト"
executable_name="UkagakaReproductionProject"
configuration="${CONFIGURATION:-release}"
version="${VERSION:-0.1.0}"
build_number="${BUILD_NUMBER:-1}"
architectures="${ARCHS:-native}"
dist_dir="${DIST_DIR:-$repo_root/dist}"
app_path="$dist_dir/$product_name.app"
executable_path="$app_path/Contents/MacOS/$executable_name"

case "$dist_dir" in
    "$repo_root"/*) ;;
    *) echo "DIST_DIR must be inside the repository: $dist_dir" >&2; exit 64 ;;
esac

mkdir -p "$dist_dir"
if [[ -e "$app_path" ]]; then
    rm -rf "$app_path"
fi
mkdir -p "$app_path/Contents/MacOS" "$app_path/Contents/Resources"

build_for_triple() {
    local triple="$1"
    swift build \
        --package-path "$repo_root" \
        --configuration "$configuration" \
        --product "$product_name" \
        --triple "$triple" \
        --jobs "${SWIFT_JOBS:-2}"
    swift build \
        --package-path "$repo_root" \
        --configuration "$configuration" \
        --triple "$triple" \
        --show-bin-path
}

if [[ "$architectures" == "universal" ]]; then
    arm_bin_dir="$(build_for_triple arm64-apple-macosx14.0 | tail -n 1)"
    intel_bin_dir="$(build_for_triple x86_64-apple-macosx14.0 | tail -n 1)"
    lipo -create \
        "$arm_bin_dir/$product_name" \
        "$intel_bin_dir/$product_name" \
        -output "$executable_path"
else
    swift build \
        --package-path "$repo_root" \
        --configuration "$configuration" \
        --product "$product_name" \
        --jobs "${SWIFT_JOBS:-2}"
    bin_dir="$(swift build --package-path "$repo_root" --configuration "$configuration" --show-bin-path)"
    cp "$bin_dir/$product_name" "$executable_path"
fi

chmod 755 "$executable_path"
ditto \
    "$repo_root/Sources/UkagakaReproductionProject/Resources/Characters" \
    "$app_path/Contents/Resources/Characters"
cp "$repo_root/Packaging/Info.plist" "$app_path/Contents/Info.plist"
"$repo_root/Scripts/make-icon.sh" \
    "$repo_root/Packaging/AppIcon.png" \
    "$app_path/Contents/Resources/AppIcon.icns"

/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $version" "$app_path/Contents/Info.plist"
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $build_number" "$app_path/Contents/Info.plist"

signing_identity="${CODE_SIGN_IDENTITY:--}"
if [[ "$signing_identity" == "-" ]]; then
    codesign --force --deep --sign - "$app_path"
else
    codesign --force --deep --options runtime --timestamp --sign "$signing_identity" "$app_path"
fi

archive_path="$dist_dir/Ukagaka-Reproduction-Project-macOS-$version.zip"
if [[ -e "$archive_path" ]]; then
    rm -f "$archive_path"
fi
ditto -c -k --sequesterRsrc --keepParent "$app_path" "$archive_path"

echo "Built: $app_path"
echo "Archive: $archive_path"
