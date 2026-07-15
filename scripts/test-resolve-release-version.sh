#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GH_CALLS="$work/gh-calls"
gh() {
  printf '%s\n' "$*" > "$GH_CALLS"
  printf '%s\n' "${FAKE_GH_RESPONSE:-null}"
}
export -f gh

actual=$(FAKE_GH_RESPONSE='{"draft":false,"prerelease":false,"tag_name":"2026.1.0"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.0)
[[ "$actual" == 2026.1.0 ]]
grep -Fxq 'api repos/unicity-aos/aos-ce/releases/tags/2026.1.0' "$GH_CALLS"

actual=$(FAKE_GH_RESPONSE='[
  {"draft":false,"prerelease":false,"tag_name":"2026.9.99"},
  {"draft":true,"prerelease":false,"tag_name":"2027.1.0"},
  {"draft":false,"prerelease":true,"tag_name":"2026.11.0"},
  {"draft":false,"prerelease":false,"tag_name":"not-a-version"},
  {"draft":false,"prerelease":false,"tag_name":"2026.10.0"},
  {"draft":false,"prerelease":false,"tag_name":"2025.99.99"}
]' \
  bash "$repo_root/scripts/resolve-release-version.sh")
[[ "$actual" == 2026.10.0 ]]
grep -Fxq 'api repos/unicity-aos/aos-ce/releases?per_page=100' "$GH_CALLS"

actual=$(FAKE_GH_RESPONSE='[
  {"draft":true,"prerelease":false,"tag_name":"2026.2.0"},
  {"draft":false,"prerelease":true,"tag_name":"2026.1.0"}
]' \
  bash "$repo_root/scripts/resolve-release-version.sh")
[[ -z "$actual" ]]

rm -f "$GH_CALLS"
if bash "$repo_root/scripts/resolve-release-version.sh" v2026.1.0 \
  > /dev/null 2>&1; then
  echo "accepted prefixed AOS version" >&2
  exit 1
fi
[[ ! -e "$GH_CALLS" ]]

if FAKE_GH_RESPONSE='{"draft":false,"prerelease":false,"tag_name":"2026.1.1"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.0 \
  > /dev/null 2>&1; then
  echo "accepted mismatched explicit AOS release tag" >&2
  exit 1
fi

if FAKE_GH_RESPONSE='{"draft":true,"prerelease":false,"tag_name":"2026.1.0"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.0 \
  > /dev/null 2>&1; then
  echo "accepted a draft AOS release" >&2
  exit 1
fi

if FAKE_GH_RESPONSE='{"draft":false,"prerelease":true,"tag_name":"2026.1.0"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.0 \
  > /dev/null 2>&1; then
  echo "accepted a prerelease AOS release" >&2
  exit 1
fi
