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
  version=$(gh api "repos/$repository/releases/tags/$requested" --jq '
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
  version=$(gh api "repos/$repository/releases?per_page=100" --jq '
    [.[] | select(.draft == false and .prerelease == false)][0].tag_name // ""
  ')
  if [[ -z "$version" ]]; then
    exit 0
  fi
  validate_version "$version"
fi

printf '%s\n' "$version"
