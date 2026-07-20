#!/bin/bash
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
app_path="${1:-$repo_root/dist/伺か再現プロジェクト.app}"
process_name="UkagakaReproductionProject"

existing_pids="$(pgrep -x "$process_name" || true)"

open -n "$app_path"
pid=""
for _ in $(seq 1 20); do
    while IFS= read -r candidate; do
        [[ -z "$candidate" ]] && continue
        if ! grep -qx "$candidate" <<< "$existing_pids"; then
            pid="$candidate"
            break
        fi
    done < <(pgrep -x "$process_name" || true)
    if [[ -n "$pid" ]]; then
        break
    fi
    sleep 0.5
done

if [[ -z "$pid" ]]; then
    echo "The app did not remain running." >&2
    exit 1
fi

sleep 2
kill -TERM "$pid"
echo "Smoke launch passed (pid $pid)."
