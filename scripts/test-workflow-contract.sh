#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
workflow="$repo_root/.github/workflows/update-formula.yml"

grep -Fq 'python-version: '\''3.12'\''' "$workflow"
grep -Fq "if: github.ref == 'refs/heads/main'" "$workflow"
grep -Fq 'scripts/discover-stable-channel.sh' "$workflow"
grep -Fq 'No signed AOS stable channel exists; the tap remains dormant.' "$workflow"
grep -Fq 'promote-channel.yml@refs/heads/main' "$workflow"
grep -Fq -- '--use-signed-timestamps' "$workflow"
grep -Fq -- '--bundle Formula/channel-stable.toml.sigstore.json' "$workflow"
grep -Fq 'scripts/channel_release.py verify-release' "$workflow"
grep -Fq "repos/unicity-aos/aos-ce/git/ref/tags/\$VERSION" "$workflow"
grep -Fq "repos/unicity-aos/aos-ce/git/tags/\$TAG_COMMIT" "$workflow"
grep -Fq "[[ \"\$TAG_TYPE\" == commit ]]" "$workflow"
grep -Fq "tap_root=\$(brew --repository unicity-aos/tap)" "$workflow"
grep -Fq "mkdir -p \"\$tap_root/Formula\"" "$workflow"
grep -Fq "cp Formula/aos.rb \"\$tap_root/Formula/aos.rb\"" "$workflow"
grep -Fq 'Formula/channel-stable.toml' "$repo_root/scripts/create-signed-commit-payload.sh"
grep -Fq 'Formula/channel-stable.toml.sigstore.json' "$repo_root/scripts/create-signed-commit-payload.sh"

ci_workflow="$repo_root/.github/workflows/ci.yml"
grep -Fq "tap_root=\$(brew --repository unicity-aos/tap)" "$ci_workflow"
grep -Fq "mkdir -p \"\$tap_root/Formula\"" "$ci_workflow"
grep -Fq "cp Formula/aos.rb \"\$tap_root/Formula/aos.rb\"" "$ci_workflow"

if grep -Fq 'inputs.version' "$workflow" || \
   grep -Fq 'REQUESTED_VERSION' "$workflow" || \
   grep -Fq 'releases/latest' "$workflow" || \
   grep -Fq "repos/unicity-aos/aos-ce/commits/\$VERSION" "$workflow"; then
  echo "workflow retains a manual or unsigned latest-version path" >&2
  exit 1
fi
