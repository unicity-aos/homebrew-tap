#!/usr/bin/env bash
set -euo pipefail

requested=${1:-}
repository=${AOS_RELEASE_REPOSITORY:-unicity-aos/aos-ce}

validate_version() {
  local version=$1
  if [[ ! "$version" =~ ^20[0-9]{2}\.[0-9]+\.[0-9]+$ ]]; then
    echo "invalid published AOS calendar-semver version: $version" >&2
    return 1
  fi
}

if [[ -n "$requested" ]]; then
  validate_version "$requested"
  release=$(gh api "repos/$repository/releases/tags/$requested")
  version=$(printf '%s\n' "$release" | jq -er '
    if .draft then
      error("requested AOS release is still a draft")
    elif .prerelease then
      error("requested AOS release is a prerelease")
    else
      .tag_name
    end
  ')
  if [[ "$version" != "$requested" ]]; then
    echo "published AOS release tag mismatch: requested $requested, got $version" >&2
    exit 1
  fi
else
  releases=$(gh api "repos/$repository/releases?per_page=100")
  version=$(printf '%s\n' "$releases" | jq -er '
    [
      .[]
      | select(.draft == false and .prerelease == false)
      | .tag_name
      | select(test("^20[0-9]{2}\\.[0-9]+\\.[0-9]+$"))
      | {tag: ., parts: (split(".") | map(tonumber))}
    ]
    | sort_by(.parts)
    | (last.tag // "")
  ')
  if [[ -z "$version" ]]; then
    exit 0
  fi
  validate_version "$version"
fi

printf '%s\n' "$version"
