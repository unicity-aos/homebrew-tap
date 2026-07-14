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

ruby -c "$formula"
grep -q 'version "2026.1.0"' "$formula"
grep -q 'UNICITY_AOS_RUNTIME_BIN' "$formula"
grep -q 'unicity-aos-aarch64-apple-darwin.tar.gz' "$formula"
grep -Fq 'assert_predicate libexec/"runtime/bin/astrid", :executable?' "$formula"
grep -Fq 'assert_predicate libexec/"runtime/bin/astrid-daemon", :executable?' "$formula"
if grep -q '@[A-Z_]*@' "$formula"; then
  echo "formula still contains a template placeholder" >&2
  exit 1
fi
