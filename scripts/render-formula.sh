#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 5 ]]; then
  echo "usage: $0 <version> <mac-arm-sha> <mac-intel-sha> <linux-arm-sha> <linux-intel-sha>" >&2
  exit 2
fi

version=$1
mac_arm=$2
mac_intel=$3
linux_arm=$4
linux_intel=$5

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
# shellcheck source=scripts/version-policy.sh
source "$repo_root/scripts/version-policy.sh"
validate_publishable_aos_version "$version"
for digest in "$mac_arm" "$mac_intel" "$linux_arm" "$linux_intel"; do
  if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
    echo "invalid SHA-256 digest" >&2
    exit 1
  fi
done

mkdir -p "$repo_root/Formula"

sed \
  -e "s/@VERSION@/$version/g" \
  -e "s/@MAC_ARM_SHA@/$mac_arm/g" \
  -e "s/@MAC_INTEL_SHA@/$mac_intel/g" \
  -e "s/@LINUX_ARM_SHA@/$linux_arm/g" \
  -e "s/@LINUX_INTEL_SHA@/$linux_intel/g" \
  "$repo_root/scripts/aos.rb.in" > "$repo_root/Formula/aos.rb"
