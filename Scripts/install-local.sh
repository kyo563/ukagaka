#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
source_app="${1:-$repo_root/dist/伺か再現プロジェクト.app}"
install_dir="${INSTALL_DIR:-$HOME/Applications}"
installed_app="$install_dir/伺か再現プロジェクト.app"

if [[ ! -d "$source_app" ]]; then
    "$repo_root/Scripts/build-app.sh"
fi

mkdir -p "$install_dir"
if [[ -d "$installed_app" ]]; then
    backup_name="伺か再現プロジェクト-previous-$(date +%Y%m%d%H%M%S).app"
    mkdir -p "$HOME/.Trash"
    mv "$installed_app" "$HOME/.Trash/$backup_name"
fi

ditto "$source_app" "$installed_app"
open "$installed_app"
echo "Installed: $installed_app"
