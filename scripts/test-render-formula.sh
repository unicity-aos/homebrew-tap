#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
formula="$repo_root/Formula/aos.rb"
backup=
if [[ -f "$formula" ]]; then
  backup=$(mktemp)
  cp "$formula" "$backup"
fi
restore() {
  if [[ -n "$backup" ]]; then
    cp "$backup" "$formula"
    rm -f "$backup"
  else
    rm -f "$formula"
  fi
}
trap restore EXIT

"$repo_root/scripts/render-formula.sh" \
  2026.1.0 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
  dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

"$repo_root/scripts/validate-formula.sh" "$formula" 2026.1.0
