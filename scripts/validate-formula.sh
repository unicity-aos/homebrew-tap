#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/aos-version.sh
source "$repo_root/scripts/aos-version.sh"

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <formula> <version>" >&2
  exit 2
fi

formula=$1
version=$2

validate_aos_version "$version"

if [[ ! -f "$formula" ]]; then
  echo "formula not found: $formula" >&2
  exit 1
fi

ruby -c "$formula"
grep -Fq "/$version/unicity-aos-$version-aarch64-apple-darwin.tar.gz" "$formula"
grep -Fq "Unicity AOS $version" "$formula"
grep -Fq 'UNICITY_AOS_RUNTIME_BIN' "$formula"
grep -Fq 'UNICITY_AOS_CAPSULE_DIR' "$formula"
grep -Fq 'libexec.install "bin", "runtime", "capsules", "capsule-assets.txt"' "$formula"
grep -Fq "unicity-aos-$version-aarch64-apple-darwin.tar.gz" "$formula"
grep -Fq 'assert_predicate libexec/"runtime/bin/astrid", :executable?' "$formula"
grep -Fq 'assert_predicate libexec/"runtime/bin/astrid-daemon", :executable?' "$formula"
grep -Fq 'system bin/"aos", "init", "--offline", "--yes"' "$formula"
grep -Fq 'runtime/home/default/.config/distro.lock' "$formula"
if grep -q '@[A-Z_]*@' "$formula"; then
  echo "formula still contains a template placeholder" >&2
  exit 1
fi
