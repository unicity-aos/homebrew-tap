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

if [[ ! "$version" =~ ^(20[0-9]{2})\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || \
   ((10#${BASH_REMATCH[1]} < 2026)); then
  echo "invalid AOS calendar-semver version: $version" >&2
  exit 1
fi
for digest in "$mac_arm" "$mac_intel" "$linux_arm" "$linux_intel"; do
  if [[ ! "$digest" =~ ^[0-9a-f]{64}$ ]]; then
    echo "invalid SHA-256 digest" >&2
    exit 1
  fi
done

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$repo_root/Formula"

sed \
  -e "s/@VERSION@/$version/g" \
  -e "s/@MAC_ARM_SHA@/$mac_arm/g" \
  -e "s/@MAC_INTEL_SHA@/$mac_intel/g" \
  -e "s/@LINUX_ARM_SHA@/$linux_arm/g" \
  -e "s/@LINUX_INTEL_SHA@/$linux_intel/g" \
  "$repo_root/scripts/aos.rb.in" > "$repo_root/Formula/aos.rb"
