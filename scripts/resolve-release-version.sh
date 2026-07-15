#!/usr/bin/env bash
set -euo pipefail

requested=${1:-}
repository=${AOS_RELEASE_REPOSITORY:-unicity-aos/aos-ce}
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/version-policy.sh
source "$repo_root/scripts/version-policy.sh"

if [[ -n "$requested" ]]; then
  validate_publishable_aos_version "$requested"
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
  releases=$(gh api --paginate --slurp "repos/$repository/releases?per_page=100")
  candidates=$(printf '%s\n' "$releases" | jq -c '
    [
      .[][]
      | select(.draft == false and .prerelease == false)
      | .tag_name
      | select(type == "string")
    ]
    | .[]
  ')
  version=
  if [[ -n "$candidates" ]]; then
    while IFS= read -r candidate_json; do
      candidate=$(printf '%s\n' "$candidate_json" | jq -er '.')
      if ! validate_publishable_aos_version "$candidate" >/dev/null 2>&1; then
        continue
      fi
      if [[ -z "$version" ]] || aos_version_is_newer "$candidate" "$version"; then
        version=$candidate
      fi
    done <<< "$candidates"
  fi
fi

printf '%s\n' "$version"
