#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/aos-version.sh
source "$repo_root/scripts/aos-version.sh"

if [[ $# -ne 6 ]]; then
  echo "usage: $0 <owner/repository> <expected-head-oid> <version> <formula> <channel> <channel-bundle>" >&2
  exit 2
fi

repository=$1
head=$2
version=$3
formula=$4
channel=$5
channel_bundle=$6

if [[ ! "$repository" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
  echo "invalid GitHub repository: $repository" >&2
  exit 1
fi
if [[ ! "$head" =~ ^[0-9a-f]{40}$ ]]; then
  echo "invalid expected head oid" >&2
  exit 1
fi
validate_aos_version "$version"
if [[ ! -f "$formula" ]]; then
  echo "formula not found: $formula" >&2
  exit 1
fi
if [[ ! -f "$channel" ]]; then
  echo "channel metadata not found: $channel" >&2
  exit 1
fi
if [[ ! -f "$channel_bundle" ]]; then
  echo "channel bundle not found: $channel_bundle" >&2
  exit 1
fi

# GraphQL variable syntax is literal.
# shellcheck disable=SC2016
query='mutation($input: CreateCommitOnBranchInput!) { createCommitOnBranch(input: $input) { commit { oid url signature { isValid wasSignedByGitHub } } } }'
formula_contents=$(base64 < "$formula" | tr -d '\n')
channel_contents=$(base64 < "$channel" | tr -d '\n')
bundle_contents=$(base64 < "$channel_bundle" | tr -d '\n')

jq -n \
  --arg query "$query" \
  --arg repository "$repository" \
  --arg head "$head" \
  --arg headline "aos $version" \
  --arg formula_contents "$formula_contents" \
  --arg channel_contents "$channel_contents" \
  --arg bundle_contents "$bundle_contents" \
  '{
    query: $query,
    variables: {
      input: {
        branch: {
          repositoryNameWithOwner: $repository,
          branchName: "main"
        },
        expectedHeadOid: $head,
        message: { headline: $headline },
        fileChanges: {
          additions: [
            { path: "Formula/aos.rb", contents: $formula_contents },
            { path: "Formula/channel-stable.toml", contents: $channel_contents },
            { path: "Formula/channel-stable.toml.sigstore.json", contents: $bundle_contents }
          ]
        }
      }
    }
  }'
