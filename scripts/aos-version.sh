#!/usr/bin/env bash

validate_aos_version() {
  local version=$1

  if [[ ! "$version" =~ ^(20[0-9]{2})\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] || \
     ((10#${BASH_REMATCH[1]} < 2026)); then
    echo "invalid AOS calendar-semver version: $version" >&2
    return 1
  fi
}
