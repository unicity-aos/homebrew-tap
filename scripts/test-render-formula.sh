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
grep -Fq '/2026.1.0/unicity-aos-2026.1.0-aarch64-apple-darwin.tar.gz' "$formula"
grep -Fq '"UNICITY_AOS_CAPSULE_DIR"    => libexec/"capsules"' "$formula"
grep -Fq 'system bin/"aos", "init", "--offline", "--yes"' "$formula"
if "$repo_root/scripts/render-formula.sh" \
  2026.01.0 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
  dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd \
  > /dev/null 2>&1; then
  echo "accepted a non-canonical calendar-semver version" >&2
  exit 1
fi
"$repo_root/scripts/render-formula.sh" \
  2026.13.0 \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
  cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc \
  dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd
"$repo_root/scripts/validate-formula.sh" "$formula" 2026.13.0
