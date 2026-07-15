#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 4 ]]; then
  echo "usage: $0 <owner/repository> <expected-head-oid> <version> <formula>" >&2
  exit 2
fi

repository=$1
head=$2
version=$3
formula=$4
repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/version-policy.sh
source "$repo_root/scripts/version-policy.sh"

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "invalid GitHub repository: $repository" >&2
  exit 1
fi
if [[ ! "$head" =~ ^[0-9a-f]{40}$ ]]; then
  echo "invalid expected head oid" >&2
  exit 1
fi
validate_publishable_aos_version "$version"
if [[ ! -f "$formula" ]]; then
  echo "formula not found: $formula" >&2
  exit 1
fi

# GraphQL variable syntax is literal.
# shellcheck disable=SC2016
query='mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid url signature { isValid wasSignedByGitHub } } } }'
contents=$(base64 < "$formula" | tr -d '\n')

jq -n \
  --arg query "$query" \
  --arg repository "$repository" \
  --arg head "$head" \
  --arg headline "aos $version" \
  --arg contents "$contents" \
  '{
    query: $query,
    variables: {
      input: {
        branch: {
          repositoryNameWithOwner: $repository,
          refName: "refs/heads/main"
        },
        expectedHeadOid: $head,
        message: { headline: $headline },
        fileChanges: {
          additions: [{ path: "Formula/aos.rb", contents: $contents }]
        }
      }
    }
  }'
