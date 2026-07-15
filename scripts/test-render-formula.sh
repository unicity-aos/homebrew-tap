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
  2026.1.1 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
  dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd

"$repo_root/scripts/validate-formula.sh" "$formula" 2026.1.1

for invalid in 2026.1.0 2026.01.1 2026.1.01 2026.1; do
  if "$repo_root/scripts/render-formula.sh" \
    "$invalid" \
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
    cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
    dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd \
    > /dev/null 2>&1; then
    echo "formula renderer accepted invalid or unsupported version: $invalid" >&2
    exit 1
  fi
done
