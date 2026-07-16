#!/usr/bin/env python3
"""Strict verification for the signed AOS stable channel and release metadata."""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import re
import sys
import tomllib
from pathlib import Path
from typing import Any


PRODUCT = "unicity-aos-ce"
REPOSITORY = "unicity-aos/aos-ce"
TARGETS = (
    "aarch64-apple-darwin",
    "x86_64-apple-darwin",
    "aarch64-unknown-linux-gnu",
    "x86_64-unknown-linux-gnu",
)
HEX_64 = re.compile(r"[0-9a-f]{64}")
COMMIT = re.compile(r"[0-9a-f]{40}")
VERSION = re.compile(r"(20[0-9]{2})\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")
SEMVER = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)")
MAX_GENERATION = 999_999_999_999_999_999
MAX_FUTURE_SKEW = dt.timedelta(minutes=5)
MAX_STABLE_LIFETIME = dt.timedelta(days=30)


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError(message)


def exact_keys(value: Any, expected: set[str], context: str) -> dict[str, Any]:
    require(isinstance(value, dict), f"{context} must be a TOML table")
    actual = set(value)
    missing = sorted(expected - actual)
    unknown = sorted(actual - expected)
    require(not missing, f"{context} is missing keys: {', '.join(missing)}")
    require(not unknown, f"{context} has unknown keys: {', '.join(unknown)}")
    return value


def string(value: Any, context: str, *, allow_empty: bool = False) -> str:
    require(isinstance(value, str), f"{context} must be a string")
    require(allow_empty or value != "", f"{context} must be non-empty")
    require("\n" not in value and "\r" not in value, f"{context} must be one line")
    return value


def timestamp(value: Any, context: str) -> dt.datetime:
    encoded = string(value, context)
    require(
        re.fullmatch(
            r"[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z",
            encoded,
        )
        is not None,
        f"{context} must be canonical UTC RFC3339 seconds",
    )
    return dt.datetime.fromisoformat(encoded.replace("Z", "+00:00"))


def version(value: Any, context: str) -> str:
    encoded = string(value, context)
    match = VERSION.fullmatch(encoded)
    require(match is not None, f"{context} must be canonical calendar semver")
    require(int(match.group(1)) >= 2026, f"{context} predates the first AOS release year")
    return encoded


def digest(value: Any, context: str) -> str:
    encoded = string(value, context)
    require(HEX_64.fullmatch(encoded) is not None, f"{context} must be lowercase hex SHA-256")
    return encoded


def commit(value: Any, context: str) -> str:
    encoded = string(value, context)
    require(COMMIT.fullmatch(encoded) is not None, f"{context} must be a lowercase 40-character commit")
    return encoded


def load_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as file:
        return tomllib.load(file)


def validate_targets(value: Any, *, release_version: str, context: str) -> dict[str, dict[str, Any]]:
    targets = exact_keys(value, set(TARGETS), context)
    for target in TARGETS:
        item = exact_keys(
            targets[target],
            {"asset", "sha256", "blake3", "sigstore-bundle", "size"},
            f"{context}.{target}",
        )
        expected_asset = f"unicity-aos-{release_version}-{target}.tar.gz"
        require(
            string(item["asset"], f"{context}.{target}.asset") == expected_asset,
            f"{context}.{target}.asset must be {expected_asset}",
        )
        require(
            string(item["sigstore-bundle"], f"{context}.{target}.sigstore-bundle")
            == f"{expected_asset}.sigstore.json",
            f"{context}.{target}.sigstore-bundle must name the exact asset bundle",
        )
        digest(item["sha256"], f"{context}.{target}.sha256")
        digest(item["blake3"], f"{context}.{target}.blake3")
        require(
            type(item["size"]) is int and item["size"] > 0,
            f"{context}.{target}.size must be a positive integer",
        )
    return targets


def validate_channel(value: Any, *, now: dt.datetime | None) -> dict[str, Any]:
    root = exact_keys(
        value,
        {
            "schema-version",
            "kind",
            "product",
            "channel",
            "generation",
            "published-at",
            "expires-at",
            "release",
            "targets",
        },
        "channel metadata",
    )
    require(type(root["schema-version"]) is int and root["schema-version"] == 1, "channel metadata schema-version must be integer 1")
    require(root["kind"] == "aos-channel", "channel metadata kind must be aos-channel")
    require(root["product"] == PRODUCT, f"channel metadata product must be {PRODUCT}")
    require(root["channel"] == "stable", "channel metadata channel must be stable")
    require(
        type(root["generation"]) is int
        and 0 < root["generation"] <= MAX_GENERATION,
        f"channel metadata generation must be between 1 and {MAX_GENERATION}",
    )
    published = timestamp(root["published-at"], "channel metadata published-at")
    expires = timestamp(root["expires-at"], "channel metadata expires-at")
    require(expires > published, "channel metadata expires-at must be after published-at")
    require(
        expires - published <= MAX_STABLE_LIFETIME,
        "channel metadata lifetime exceeds the stable maximum",
    )
    if now is not None:
        require(now <= expires, "channel metadata has expired")
        require(
            published <= now + MAX_FUTURE_SKEW,
            "channel metadata published-at is unreasonably far in the future",
        )

    release = exact_keys(
        root["release"],
        {
            "repository",
            "version",
            "tag",
            "source-commit",
            "metadata-asset",
            "metadata-sha256",
            "release-workflow-identity",
        },
        "channel metadata.release",
    )
    require(release["repository"] == REPOSITORY, f"channel release repository must be {REPOSITORY}")
    release_version = version(release["version"], "channel metadata.release.version")
    require(release["tag"] == release_version, "channel release tag must equal version")
    commit(release["source-commit"], "channel metadata.release.source-commit")
    require(
        release["metadata-asset"] == f"unicity-aos-{release_version}-release.toml",
        "channel release metadata asset is not canonical",
    )
    digest(release["metadata-sha256"], "channel metadata.release.metadata-sha256")
    expected_identity = (
        f"https://github.com/{REPOSITORY}/.github/workflows/"
        f"release.yml@refs/tags/{release_version}"
    )
    require(
        release["release-workflow-identity"] == expected_identity,
        "channel release workflow identity must be the exact release tag identity",
    )
    validate_targets(root["targets"], release_version=release_version, context="channel metadata.targets")
    return root


def validate_release(value: Any, *, require_ready: bool) -> dict[str, Any]:
    root = exact_keys(
        value,
        {
            "schema-version",
            "kind",
            "product",
            "version",
            "tag",
            "source-commit",
            "published-at",
            "release-workflow-identity",
            "runtime",
            "contracts",
            "gates",
            "targets",
        },
        "release metadata",
    )
    require(type(root["schema-version"]) is int and root["schema-version"] == 1, "release metadata schema-version must be integer 1")
    require(root["kind"] == "aos-release", "release metadata kind must be aos-release")
    require(root["product"] == PRODUCT, f"release metadata product must be {PRODUCT}")
    release_version = version(root["version"], "release metadata version")
    require(root["tag"] == release_version, "release metadata tag must equal version")
    commit(root["source-commit"], "release metadata source-commit")
    timestamp(root["published-at"], "release metadata published-at")
    expected_identity = (
        f"https://github.com/{REPOSITORY}/.github/workflows/"
        f"release.yml@refs/tags/{release_version}"
    )
    require(root["release-workflow-identity"] == expected_identity, "release metadata workflow identity must be the exact tag identity")

    runtime = exact_keys(
        root["runtime"],
        {
            "repository",
            "version",
            "tag",
            "release-workflow-identity",
            "release-metadata-available",
            "source-commit",
            "release-metadata-asset",
            "release-metadata-blake3",
        },
        "release metadata.runtime",
    )
    require(runtime["repository"] == "astrid-runtime/astrid", "release metadata runtime repository must be astrid-runtime/astrid")
    runtime_version = string(runtime["version"], "release metadata.runtime.version")
    require(SEMVER.fullmatch(runtime_version) is not None, "release metadata runtime version must be canonical semver")
    require(runtime["tag"] == f"v{runtime_version}", "release metadata runtime tag/version mismatch")
    runtime_identity = string(runtime["release-workflow-identity"], "release metadata.runtime.release-workflow-identity")
    require(
        runtime_identity in {
            f"https://github.com/astrid-runtime/astrid/.github/workflows/release.yml@refs/tags/v{runtime_version}",
            f"https://github.com/unicity-astrid/astrid/.github/workflows/release.yml@refs/tags/v{runtime_version}",
        },
        "release metadata runtime workflow identity is not an approved exact tag identity",
    )
    require(type(runtime["release-metadata-available"]) is bool, "release metadata.runtime.release-metadata-available must be a boolean")
    if runtime["release-metadata-available"]:
        require(runtime_identity.startswith("https://github.com/astrid-runtime/astrid/"), "new Astrid release metadata must use the astrid-runtime workflow identity")
        commit(runtime["source-commit"], "release metadata.runtime.source-commit")
        require(
            runtime["release-metadata-asset"] == f"astrid-{runtime['version']}-release.toml",
            "release metadata runtime metadata asset is not canonical",
        )
        digest(runtime["release-metadata-blake3"], "release metadata.runtime.release-metadata-blake3")
    else:
        for key in ("source-commit", "release-metadata-asset", "release-metadata-blake3"):
            require(
                string(runtime[key], f"release metadata.runtime.{key}", allow_empty=True) == "",
                f"release metadata.runtime.{key} must be empty while metadata is unavailable",
            )

    contracts = exact_keys(
        root["contracts"],
        {"repository", "commit", "sdk-rust-version", "sdk-rust-commit"},
        "release metadata.contracts",
    )
    require(contracts["repository"] == "astrid-runtime/wit", "release metadata contracts repository must be astrid-runtime/wit")
    require(SEMVER.fullmatch(string(contracts["sdk-rust-version"], "release metadata.contracts.sdk-rust-version")) is not None, "release metadata SDK version must be canonical semver")
    commit(contracts["commit"], "release metadata.contracts.commit")
    commit(contracts["sdk-rust-commit"], "release metadata.contracts.sdk-rust-commit")

    gates = exact_keys(root["gates"], {"release-ready", "upgrade-self-heal-ready"}, "release metadata.gates")
    for key in ("release-ready", "upgrade-self-heal-ready"):
        require(type(gates[key]) is bool, f"release metadata.gates.{key} must be a boolean")
        if require_ready:
            require(gates[key], f"release metadata {key} gate is false")

    validate_targets(root["targets"], release_version=release_version, context="release metadata.targets")
    return root


def parse_now(value: str | None) -> dt.datetime:
    if value is None:
        return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)
    return timestamp(value, "current time")


def inspect_channel(args: argparse.Namespace) -> None:
    current_bytes = args.channel.read_bytes()
    current_bundle = args.channel_bundle.read_bytes()
    current = validate_channel(load_toml(args.channel), now=parse_now(args.now))
    status = "initial"
    if args.accepted_channel is not None or args.accepted_bundle is not None:
        require(args.accepted_channel is not None and args.accepted_bundle is not None, "accepted channel and bundle must be supplied together")
        require(args.accepted_channel.is_file(), "accepted channel metadata is missing")
        require(args.accepted_bundle.is_file(), "accepted channel bundle is missing")
        accepted = validate_channel(load_toml(args.accepted_channel), now=None)
        require(current["generation"] >= accepted["generation"], "stable channel generation rollback rejected")
        if current["generation"] == accepted["generation"]:
            require(current_bytes == args.accepted_channel.read_bytes(), "stable channel same-generation equivocation rejected")
            status = "unchanged" if current_bundle == args.accepted_bundle.read_bytes() else "proof-refresh"
        else:
            status = "advance"

    release = current["release"]
    print(
        json.dumps(
            {
                "status": status,
                "generation": current["generation"],
                "version": release["version"],
                "tag": release["tag"],
                "source_commit": release["source-commit"],
                "metadata_asset": release["metadata-asset"],
                "metadata_sha256": release["metadata-sha256"],
                "release_workflow_identity": release["release-workflow-identity"],
            },
            sort_keys=True,
        )
    )


def verify_release(args: argparse.Namespace) -> None:
    channel = validate_channel(load_toml(args.channel), now=parse_now(args.now))
    release_bytes = args.release.read_bytes()
    require(
        hashlib.sha256(release_bytes).hexdigest() == channel["release"]["metadata-sha256"],
        "release metadata SHA-256 does not match the signed channel pointer",
    )
    release = validate_release(load_toml(args.release), require_ready=True)
    for key in ("version", "tag", "source-commit", "release-workflow-identity"):
        require(release[key] == channel["release"][key], f"release metadata {key} does not match the signed channel pointer")
    require(
        release["targets"] == channel["targets"],
        "release metadata target tables do not exactly match the signed channel pointer",
    )
    state = json.loads(args.release_state.read_text(encoding="utf-8"))
    exact_keys(state, {"isDraft", "isPrerelease", "tagName"}, "GitHub release state")
    require(type(state["isDraft"]) is bool and not state["isDraft"], "stable AOS release must not be a draft")
    require(type(state["isPrerelease"]) is bool and not state["isPrerelease"], "stable AOS release must not be a prerelease")
    require(state["tagName"] == release["tag"], "GitHub release tag does not match signed metadata")
    require(
        commit(args.tag_commit, "release tag commit") == release["source-commit"],
        "release source commit does not match the tag commit",
    )
    print(
        json.dumps(
            {
                "version": release["version"],
                "generation": channel["generation"],
                "targets": {
                    target: {
                        "asset": release["targets"][target]["asset"],
                        "sha256": release["targets"][target]["sha256"],
                    }
                    for target in TARGETS
                },
            },
            sort_keys=True,
        )
    )


def parser() -> argparse.ArgumentParser:
    root = argparse.ArgumentParser()
    commands = root.add_subparsers(dest="command", required=True)
    inspect = commands.add_parser("inspect-channel")
    inspect.add_argument("--channel", type=Path, required=True)
    inspect.add_argument("--channel-bundle", type=Path, required=True)
    inspect.add_argument("--accepted-channel", type=Path)
    inspect.add_argument("--accepted-bundle", type=Path)
    inspect.add_argument("--now")
    inspect.set_defaults(func=inspect_channel)
    verify = commands.add_parser("verify-release")
    verify.add_argument("--channel", type=Path, required=True)
    verify.add_argument("--release", type=Path, required=True)
    verify.add_argument("--release-state", type=Path, required=True)
    verify.add_argument("--tag-commit", required=True)
    verify.add_argument("--now")
    verify.set_defaults(func=verify_release)
    return root


def main() -> int:
    args = parser().parse_args()
    try:
        args.func(args)
    except (OSError, ValueError, tomllib.TOMLDecodeError, json.JSONDecodeError) as error:
        print(f"stable channel verification failed: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
