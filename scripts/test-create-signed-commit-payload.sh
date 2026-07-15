#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

formula="$work/aos.rb"
payload="$work/payload.json"
printf 'class Aos < Formula\nend\n' > "$formula"

"$repo_root/scripts/create-signed-commit-payload.sh" \
  unicity-aos/homebrew-tap \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  2026.1.1 \
  "$formula" > "$payload"

expected_contents=$(base64 < "$formula" | tr -d '\n')
jq -e \
  --arg contents "$expected_contents" \
  '.variables.input == {
    branch: {
      repositoryNameWithOwner: "unicity-aos/homebrew-tap",
      refName: "refs/heads/main"
    },
    expectedHeadOid: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    message: { headline: "aos 2026.1.1" },
    fileChanges: {
      additions: [{ path: "Formula/aos.rb", contents: $contents }]
    }
  }' "$payload" > /dev/null
jq -e \
  '.query | contains("signature { isValid wasSignedByGitHub }")' \
  "$payload" > /dev/null

if "$repo_root/scripts/create-signed-commit-payload.sh" \
  unicity-aos/homebrew-tap not-a-commit 2026.1.1 "$formula" > /dev/null 2>&1; then
  echo "payload builder accepted an invalid expected head" >&2
  exit 1
fi

for invalid in 2026.1.0 2026.01.1 2026.1.01 2026.1; do
  if "$repo_root/scripts/create-signed-commit-payload.sh" \
    unicity-aos/homebrew-tap \
    aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
    "$invalid" \
    "$formula" \
    > /dev/null 2>&1; then
    echo "payload builder accepted invalid or unsupported version: $invalid" >&2
    exit 1
  fi
done
