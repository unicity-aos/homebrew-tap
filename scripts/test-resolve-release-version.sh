#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GH_CALLS="$work/gh-calls"
gh() {
  printf '%s\n' "$*" > "$GH_CALLS"
  printf '%s\n' "${FAKE_RELEASE_VERSION:-}"
}
export -f gh

actual=$(FAKE_RELEASE_VERSION=2026.1.0 \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.0)
[[ "$actual" == 2026.1.0 ]]
grep -Fq 'api repos/unicity-aos/aos-ce/releases/tags/2026.1.0 --jq' "$GH_CALLS"
grep -Fq 'requested AOS release is a prerelease' "$GH_CALLS"

actual=$(FAKE_RELEASE_VERSION=2026.2.3 \
  bash "$repo_root/scripts/resolve-release-version.sh")
[[ "$actual" == 2026.2.3 ]]
grep -Fq 'api repos/unicity-aos/aos-ce/releases?per_page=100 --jq' "$GH_CALLS"
grep -Fq 'prerelease == false' "$GH_CALLS"

actual=$(FAKE_RELEASE_VERSION='' \
  bash "$repo_root/scripts/resolve-release-version.sh")
[[ -z "$actual" ]]

rm -f "$GH_CALLS"
if bash "$repo_root/scripts/resolve-release-version.sh" v2026.1.0 \
  > /dev/null 2>&1; then
  echo "accepted prefixed AOS version" >&2
  exit 1
fi
[[ ! -e "$GH_CALLS" ]]

if FAKE_RELEASE_VERSION=2026.1.1 \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.0 \
  > /dev/null 2>&1; then
  echo "accepted mismatched explicit AOS release tag" >&2
  exit 1
fi

if FAKE_RELEASE_VERSION=nightly \
  bash "$repo_root/scripts/resolve-release-version.sh" > /dev/null 2>&1; then
  echo "accepted invalid published AOS version" >&2
  exit 1
fi
