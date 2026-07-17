#!/usr/bin/env bash
set -euo pipefail

repository=${AOS_RELEASE_REPOSITORY:-unicity-aos/aos-ce}

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "invalid AOS release repository: $repository" >&2
  exit 1
fi

owner=${repository%%/*}
name=${repository#*/}

# A missing channel-stable release is the expected pre-release state. GraphQL
# returns a successful response with a null release, while authentication,
# transport, and API failures remain fatal.
# GraphQL variables are literal, not shell expansions.
# shellcheck disable=SC2016
release=$(gh api graphql \
  -f owner="$owner" \
  -f name="$name" \
  -f tag=channel-stable \
  -f query='query($owner:String!,$name:String!,$tag:String!){repository(owner:$owner,name:$name){release(tagName:$tag){tagName}}}' \
  --jq '.data.repository | if . == null then error("AOS release repository not found") else .release.tagName // "" end')

if [[ -z "$release" ]]; then
  exit 0
fi
if [[ "$release" != channel-stable ]]; then
  echo "unexpected AOS stable channel tag: $release" >&2
  exit 1
fi

printf '%s\n' "$release"
