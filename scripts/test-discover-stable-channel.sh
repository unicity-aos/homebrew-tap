#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

export GH_CALLS="$work/gh-calls"
gh() {
  printf '%s\n' "$*" > "$GH_CALLS"
  if [[ "${FAKE_GH_FAILURE:-false}" == true ]]; then
    return 1
  fi
  printf '%s\n' "${FAKE_CHANNEL_TAG:-}"
}
export -f gh

actual=$(FAKE_CHANNEL_TAG='' bash "$repo_root/scripts/discover-stable-channel.sh")
[[ -z "$actual" ]]
# The GraphQL variable is expected to remain literal.
# shellcheck disable=SC2016
grep -Fq 'release(tagName:$tag)' "$GH_CALLS"
grep -Fq 'AOS release repository not found' "$GH_CALLS"

actual=$(FAKE_CHANNEL_TAG=channel-stable bash "$repo_root/scripts/discover-stable-channel.sh")
[[ "$actual" == channel-stable ]]

if FAKE_CHANNEL_TAG=2026.1.0 \
  bash "$repo_root/scripts/discover-stable-channel.sh" > /dev/null 2>&1; then
  echo "accepted an unexpected channel release tag" >&2
  exit 1
fi

if FAKE_GH_FAILURE=true \
  bash "$repo_root/scripts/discover-stable-channel.sh" > /dev/null 2>&1; then
  echo "treated an API failure as a dormant channel" >&2
  exit 1
fi

if AOS_RELEASE_REPOSITORY=invalid \
  bash "$repo_root/scripts/discover-stable-channel.sh" > /dev/null 2>&1; then
  echo "accepted an invalid release repository" >&2
  exit 1
fi
