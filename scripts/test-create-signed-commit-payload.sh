#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

formula="$work/aos.rb"
channel="$work/channel.toml"
bundle="$work/channel.toml.sigstore.json"
payload="$work/payload.json"
printf 'class Aos < Formula\nend\n' > "$formula"
printf 'generation = 1\n' > "$channel"
printf '{"bundle":"fixture"}\n' > "$bundle"

"$repo_root/scripts/create-signed-commit-payload.sh" \
  unicity-aos/homebrew-tap \
  aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
  2026.1.0 \
  "$formula" \
  "$channel" \
  "$bundle" > "$payload"

formula_contents=$(base64 < "$formula" | tr -d '\n')
channel_contents=$(base64 < "$channel" | tr -d '\n')
bundle_contents=$(base64 < "$bundle" | tr -d '\n')
jq -e \
  --arg formula_contents "$formula_contents" \
  --arg channel_contents "$channel_contents" \
  --arg bundle_contents "$bundle_contents" \
  '.variables.input == {
    branch: {
      repositoryNameWithOwner: "unicity-aos/homebrew-tap",
      branchName: "main"
    },
    expectedHeadOid: "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
    message: { headline: "aos 2026.1.0" },
    fileChanges: {
      additions: [
        { path: "Formula/aos.rb", contents: $formula_contents },
        { path: "Formula/channel-stable.toml", contents: $channel_contents },
        { path: "Formula/channel-stable.toml.sigstore.json", contents: $bundle_contents }
      ]
    }
  }' "$payload" > /dev/null
jq -e \
  '.query | contains("signature { isValid wasSignedByGitHub }")' \
  "$payload" > /dev/null

if "$repo_root/scripts/create-signed-commit-payload.sh" \
  unicity-aos/homebrew-tap not-a-commit 2026.1.0 "$formula" "$channel" "$bundle" > /dev/null 2>&1; then
  echo "payload builder accepted an invalid expected head" >&2
  exit 1
fi
