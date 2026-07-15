#!/usr/bin/env bash

# Canonical AOS release versions use calendar years and byte-preserving numeric
# components. The minimum is the first version supported by this tap.
readonly AOS_CALENDAR_VERSION_REGEX='^20[0-9]{2}\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$'
readonly AOS_MIN_PUBLISHABLE_VERSION='2026.1.1'

validate_aos_calendar_version() {
  local version=$1
  if [[ ! "$version" =~ $AOS_CALENDAR_VERSION_REGEX ]]; then
    echo "invalid AOS calendar-semver version: $version" >&2
    return 1
  fi
}

compare_decimal_components() {
  local left=$1
  local right=$2

  if (( ${#left} < ${#right} )); then
    printf '%s\n' -1
  elif (( ${#left} > ${#right} )); then
    printf '%s\n' 1
  elif [[ "$left" == "$right" ]]; then
    printf '%s\n' 0
  elif [[ "$left" > "$right" ]]; then
    printf '%s\n' 1
  else
    printf '%s\n' -1
  fi
}

compare_aos_versions() {
  local left=$1
  local right=$2
  local left_parts right_parts index comparison

  validate_aos_calendar_version "$left" >/dev/null || return 1
  validate_aos_calendar_version "$right" >/dev/null || return 1
  IFS=. read -r -a left_parts <<< "$left"
  IFS=. read -r -a right_parts <<< "$right"

  for index in 0 1 2; do
    comparison=$(compare_decimal_components \
      "${left_parts[$index]}" "${right_parts[$index]}")
    if [[ "$comparison" != 0 ]]; then
      printf '%s\n' "$comparison"
      return
    fi
  done
  printf '%s\n' 0
}

validate_publishable_aos_version() {
  local version=$1
  local comparison

  validate_aos_calendar_version "$version" || return 1
  comparison=$(compare_aos_versions "$version" "$AOS_MIN_PUBLISHABLE_VERSION") || return 1
  if [[ "$comparison" == -1 ]]; then
    echo "unsupported AOS release version: $version (minimum $AOS_MIN_PUBLISHABLE_VERSION)" >&2
    return 1
  fi
}

aos_version_is_newer() {
  [[ $(compare_aos_versions "$1" "$2") == 1 ]]
}
