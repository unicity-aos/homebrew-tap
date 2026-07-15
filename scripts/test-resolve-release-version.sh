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

actual=$(FAKE_GH_RESPONSE='{"draft":false,"prerelease":false,"tag_name":"2026.1.1"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.1)
[[ "$actual" == 2026.1.1 ]]
grep -Fxq 'api repos/unicity-aos/aos-ce/releases/tags/2026.1.1' "$GH_CALLS"

# The paginated response is a JSON array of pages, as produced by
# `gh api --paginate --slurp`. The numeric maximum deliberately lives later.
actual=$(FAKE_GH_RESPONSE='[
  [
    {"draft":false,"prerelease":false,"tag_name":"2026.9.99"},
    {"draft":true,"prerelease":false,"tag_name":"2028.1.0"},
    {"draft":false,"prerelease":true,"tag_name":"2027.11.0"},
    {"draft":false,"prerelease":false,"tag_name":"not-a-version"},
    {"draft":false,"prerelease":false,"tag_name":"junk\n2029.1.1"},
    {"draft":false,"prerelease":false,"tag_name":"2026.10.0"},
    {"draft":false,"prerelease":false,"tag_name":"2026.01.200"}
  ],
  [
    {"draft":false,"prerelease":false,"tag_name":"2027.2.0"},
    {"draft":false,"prerelease":false,"tag_name":"2027.1.999"},
    {"draft":false,"prerelease":false,"tag_name":"2026.10.01"}
  ]
]' bash "$repo_root/scripts/resolve-release-version.sh")
[[ "$actual" == 2027.2.0 ]]
grep -Fxq 'api --paginate --slurp repos/unicity-aos/aos-ce/releases?per_page=100' "$GH_CALLS"

# Releases older than the tap's minimum are ignored during automatic
# discovery, including when one would otherwise be the numeric maximum.
actual=$(FAKE_GH_RESPONSE='[[
  {"draft":false,"prerelease":false,"tag_name":"2026.1.0"},
  {"draft":false,"prerelease":false,"tag_name":"2025.99.99"}
]]' bash "$repo_root/scripts/resolve-release-version.sh")
[[ -z "$actual" ]]

actual=$(FAKE_GH_RESPONSE='[[
  {"draft":true,"prerelease":false,"tag_name":"2026.2.0"},
  {"draft":false,"prerelease":true,"tag_name":"2026.1.1"}
]]' bash "$repo_root/scripts/resolve-release-version.sh")
[[ -z "$actual" ]]

for invalid in \
  v2026.1.1 \
  2026.01.1 \
  2026.1.01 \
  2026.1 \
  1999.1.1 \
  2026.1.0; do
  rm -f "$GH_CALLS"
  if bash "$repo_root/scripts/resolve-release-version.sh" "$invalid" \
    > /dev/null 2>&1; then
    echo "accepted invalid or unsupported AOS version: $invalid" >&2
    exit 1
  fi
  [[ ! -e "$GH_CALLS" ]]
done

if FAKE_GH_RESPONSE='{"draft":false,"prerelease":false,"tag_name":"2026.1.2"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.1 \
  > /dev/null 2>&1; then
  echo "accepted mismatched explicit AOS release tag" >&2
  exit 1
fi

if FAKE_GH_RESPONSE='{"draft":true,"prerelease":false,"tag_name":"2026.1.1"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.1 \
  > /dev/null 2>&1; then
  echo "accepted a draft AOS release" >&2
  exit 1
fi

if FAKE_GH_RESPONSE='{"draft":false,"prerelease":true,"tag_name":"2026.1.1"}' \
  bash "$repo_root/scripts/resolve-release-version.sh" 2026.1.1 \
  > /dev/null 2>&1; then
  echo "accepted a prerelease AOS release" >&2
  exit 1
fi

if FAKE_GH_RESPONSE='not-json' \
  bash "$repo_root/scripts/resolve-release-version.sh" > /dev/null 2>&1; then
  echo "accepted malformed paginated release JSON" >&2
  exit 1
fi
