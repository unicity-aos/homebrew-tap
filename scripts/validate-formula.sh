#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 2 ]]; then
  echo "usage: $0 <formula> <version>" >&2
  exit 2
fi

formula=$1
version=$2
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/version-policy.sh
source "$repo_root/scripts/version-policy.sh"

validate_publishable_aos_version "$version"

if [[ ! -f "$formula" ]]; then
  echo "formula not found: $formula" >&2
  exit 1
fi

ruby -c "$formula"
grep -Fq "/$version/unicity-aos-aarch64-apple-darwin.tar.gz" "$formula"
grep -Fq "Unicity AOS $version" "$formula"
grep -Fq 'UNICITY_AOS_RUNTIME_BIN' "$formula"
grep -Fq 'UNICITY_AOS_CAPSULE_DIR' "$formula"
grep -Fq 'libexec.install "bin", "runtime", "capsules"' "$formula"
grep -Fq 'unicity-aos-aarch64-apple-darwin.tar.gz' "$formula"
grep -Fq 'assert_predicate libexec/"runtime/bin/astrid", :executable?' "$formula"
grep -Fq 'assert_predicate libexec/"runtime/bin/astrid-daemon", :executable?' "$formula"
grep -Fq 'assert_predicate libexec/"capsules/astrid-capsule-cli.capsule", :file?' "$formula"
grep -Fq 'assert_predicate libexec/"capsules/astrid-capsule-http.capsule", :file?' "$formula"
if grep -q '@[A-Z_]*@' "$formula"; then
  echo "formula still contains a template placeholder" >&2
  exit 1
fi
