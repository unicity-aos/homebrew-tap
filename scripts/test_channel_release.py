#!/usr/bin/env python3
"""Regression tests for the Homebrew stable-channel trust chain."""

from __future__ import annotations

import argparse
import contextlib
import copy
import datetime as dt
import hashlib
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path


SCRIPT = Path(__file__).with_name("channel_release.py")
SPEC = importlib.util.spec_from_file_location("channel_release", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError("could not load channel release module")
METADATA = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(METADATA)


def targets(version: str) -> dict[str, dict[str, object]]:
    result = {}
    for index, target in enumerate(METADATA.TARGETS, 1):
        asset = f"unicity-aos-{version}-{target}.tar.gz"
        result[target] = {
            "asset": asset,
            "sha256": f"{index:064x}",
            "blake3": f"{index + 10:064x}",
            "sigstore-bundle": f"{asset}.sigstore.json",
            "size": index,
        }
    return result


def release_fixture(version: str = "2026.1.0") -> dict[str, object]:
    identity = (
        "https://github.com/unicity-aos/aos-ce/.github/workflows/"
        f"release.yml@refs/tags/{version}"
    )
    return {
        "schema-version": 1,
        "kind": "aos-release",
        "product": "unicity-aos-ce",
        "version": version,
        "tag": version,
        "source-commit": "a" * 40,
        "published-at": "2026-07-16T10:00:00Z",
        "release-workflow-identity": identity,
        "runtime": {
            "repository": "astrid-runtime/astrid",
            "version": "0.9.4",
            "tag": "v0.9.4",
            "release-workflow-identity": (
                "https://github.com/astrid-runtime/astrid/.github/workflows/"
                "release.yml@refs/tags/v0.9.4"
            ),
            "release-metadata-available": False,
            "source-commit": "",
            "release-metadata-asset": "",
            "release-metadata-blake3": "",
        },
        "contracts": {
            "repository": "astrid-runtime/wit",
            "commit": "b" * 40,
            "sdk-rust-version": "0.7.1",
            "sdk-rust-commit": "c" * 40,
        },
        "gates": {"release-ready": True, "upgrade-self-heal-ready": True},
        "targets": targets(version),
    }


def channel_fixture(
    release: dict[str, object],
    release_sha: str,
    *,
    generation: int = 1,
) -> dict[str, object]:
    version = release["version"]
    return {
        "schema-version": 1,
        "kind": "aos-channel",
        "product": "unicity-aos-ce",
        "channel": "stable",
        "generation": generation,
        "published-at": "2026-07-16T10:00:00Z",
        "expires-at": "2026-08-15T10:00:00Z",
        "release": {
            "repository": "unicity-aos/aos-ce",
            "version": version,
            "tag": version,
            "source-commit": release["source-commit"],
            "metadata-asset": f"unicity-aos-{version}-release.toml",
            "metadata-sha256": release_sha,
            "release-workflow-identity": release["release-workflow-identity"],
        },
        "targets": copy.deepcopy(release["targets"]),
    }


def write_targets(lines: list[str], value: dict[str, dict[str, object]]) -> None:
    for target in METADATA.TARGETS:
        item = value[target]
        lines.extend(
            [
                "",
                f"[targets.{target}]",
                f'asset = "{item["asset"]}"',
                f'sha256 = "{item["sha256"]}"',
                f'blake3 = "{item["blake3"]}"',
                f'sigstore-bundle = "{item["sigstore-bundle"]}"',
                f'size = {item["size"]}',
            ]
        )


def write_release(path: Path, value: dict[str, object]) -> None:
    runtime = value["runtime"]
    contracts = value["contracts"]
    gates = value["gates"]
    lines = [
        f'schema-version = {value["schema-version"]}',
        f'kind = "{value["kind"]}"',
        f'product = "{value["product"]}"',
        f'version = "{value["version"]}"',
        f'tag = "{value["tag"]}"',
        f'source-commit = "{value["source-commit"]}"',
        f'published-at = "{value["published-at"]}"',
        f'release-workflow-identity = "{value["release-workflow-identity"]}"',
        "",
        "[runtime]",
        f'repository = "{runtime["repository"]}"',
        f'version = "{runtime["version"]}"',
        f'tag = "{runtime["tag"]}"',
        f'release-workflow-identity = "{runtime["release-workflow-identity"]}"',
        f'release-metadata-available = {str(runtime["release-metadata-available"]).lower()}',
        f'source-commit = "{runtime["source-commit"]}"',
        f'release-metadata-asset = "{runtime["release-metadata-asset"]}"',
        f'release-metadata-blake3 = "{runtime["release-metadata-blake3"]}"',
        "",
        "[contracts]",
        f'repository = "{contracts["repository"]}"',
        f'commit = "{contracts["commit"]}"',
        f'sdk-rust-version = "{contracts["sdk-rust-version"]}"',
        f'sdk-rust-commit = "{contracts["sdk-rust-commit"]}"',
        "",
        "[gates]",
        f'release-ready = {str(gates["release-ready"]).lower()}',
        f'upgrade-self-heal-ready = {str(gates["upgrade-self-heal-ready"]).lower()}',
    ]
    write_targets(lines, value["targets"])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_channel(path: Path, value: dict[str, object]) -> None:
    release = value["release"]
    lines = [
        f'schema-version = {value["schema-version"]}',
        f'kind = "{value["kind"]}"',
        f'product = "{value["product"]}"',
        f'channel = "{value["channel"]}"',
        f'generation = {value["generation"]}',
        f'published-at = "{value["published-at"]}"',
        f'expires-at = "{value["expires-at"]}"',
        "",
        "[release]",
        f'repository = "{release["repository"]}"',
        f'version = "{release["version"]}"',
        f'tag = "{release["tag"]}"',
        f'source-commit = "{release["source-commit"]}"',
        f'metadata-asset = "{release["metadata-asset"]}"',
        f'metadata-sha256 = "{release["metadata-sha256"]}"',
        f'release-workflow-identity = "{release["release-workflow-identity"]}"',
    ]
    write_targets(lines, value["targets"])
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


class StableChannelTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.bundle = self.root / "channel.toml.sigstore.json"
        self.bundle.write_text('{"fixture":true}\n', encoding="utf-8")

    def channel(self, value: dict[str, object], name: str = "channel.toml") -> Path:
        path = self.root / name
        write_channel(path, value)
        return path

    def inspect(self, current: Path, accepted: Path | None = None, accepted_bundle: Path | None = None) -> dict[str, object]:
        args = argparse.Namespace(
            channel=current,
            channel_bundle=self.bundle,
            accepted_channel=accepted,
            accepted_bundle=accepted_bundle,
            now="2026-07-17T00:00:00Z",
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            METADATA.inspect_channel(args)
        return json.loads(output.getvalue())

    def test_first_signed_channel_is_initial(self) -> None:
        release = release_fixture()
        channel = channel_fixture(release, "d" * 64)
        self.assertEqual(self.inspect(self.channel(channel))["status"], "initial")

    def test_generation_rollback_is_rejected(self) -> None:
        release = release_fixture()
        accepted = self.channel(channel_fixture(release, "d" * 64, generation=8), "accepted.toml")
        current = self.channel(channel_fixture(release, "d" * 64, generation=7))
        with self.assertRaisesRegex(ValueError, "generation rollback"):
            self.inspect(current, accepted, self.bundle)

    def test_same_generation_equivocation_is_rejected(self) -> None:
        release = release_fixture()
        accepted_value = channel_fixture(release, "d" * 64, generation=7)
        accepted = self.channel(accepted_value, "accepted.toml")
        current_value = copy.deepcopy(accepted_value)
        current_value["published-at"] = "2026-07-16T11:00:00Z"
        current = self.channel(current_value)
        with self.assertRaisesRegex(ValueError, "same-generation equivocation"):
            self.inspect(current, accepted, self.bundle)

    def test_same_generation_exact_evidence_is_unchanged(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64, generation=7)
        accepted = self.channel(value, "accepted.toml")
        current = self.channel(value)
        self.assertEqual(self.inspect(current, accepted, self.bundle)["status"], "unchanged")

    def test_same_generation_valid_proof_rotation_is_published(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64, generation=7)
        accepted = self.channel(value, "accepted.toml")
        accepted_bundle = self.root / "accepted-bundle.json"
        accepted_bundle.write_text('{"fixture":false}\n', encoding="utf-8")
        current = self.channel(value)
        self.assertEqual(
            self.inspect(current, accepted, accepted_bundle)["status"],
            "proof-refresh",
        )

    def test_higher_generation_may_intentionally_select_older_product(self) -> None:
        accepted_release = release_fixture("2026.2.0")
        accepted = self.channel(channel_fixture(accepted_release, "e" * 64, generation=7), "accepted.toml")
        current_release = release_fixture("2026.1.0")
        current = self.channel(channel_fixture(current_release, "d" * 64, generation=8))
        result = self.inspect(current, accepted, self.bundle)
        self.assertEqual((result["status"], result["version"]), ("advance", "2026.1.0"))

    def test_expired_channel_is_rejected(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        value["expires-at"] = "2026-07-16T12:00:00Z"
        with self.assertRaisesRegex(ValueError, "expired"):
            self.inspect(self.channel(value))

    def test_excessive_stable_lifetime_is_rejected(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        value["expires-at"] = "2026-08-15T10:00:01Z"
        with self.assertRaisesRegex(ValueError, "stable maximum"):
            METADATA.validate_channel(
                value,
                now=dt.datetime(2026, 7, 17, tzinfo=dt.timezone.utc),
            )

    def test_unreasonable_future_publication_is_rejected(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        with self.assertRaisesRegex(ValueError, "far in the future"):
            METADATA.validate_channel(
                value,
                now=dt.datetime(2026, 7, 16, 9, 54, 59, tzinfo=dt.timezone.utc),
            )

    def test_channel_is_strictly_stable(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        value["channel"] = "dev"
        with self.assertRaisesRegex(ValueError, "must be stable"):
            METADATA.validate_channel(value, now=None)

    def test_noncanonical_calendar_semver_is_rejected(self) -> None:
        release = release_fixture("2026.01.0")
        value = channel_fixture(release, "d" * 64)
        with self.assertRaisesRegex(ValueError, "calendar semver"):
            METADATA.validate_channel(value, now=None)

    def test_minor_above_twelve_is_valid_semver(self) -> None:
        release = release_fixture("2026.13.0")
        value = channel_fixture(release, "d" * 64)
        result = METADATA.validate_channel(value, now=None)
        self.assertEqual(result["release"]["version"], "2026.13.0")

    def test_version_before_first_release_year_is_rejected(self) -> None:
        release = release_fixture("2025.12.0")
        value = channel_fixture(release, "d" * 64)
        with self.assertRaisesRegex(ValueError, "predates"):
            METADATA.validate_channel(value, now=None)

    def test_channel_schema_rejects_unknown_fields(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        value["latest"] = True
        with self.assertRaisesRegex(ValueError, "unknown keys: latest"):
            METADATA.validate_channel(value, now=None)

    def test_boolean_generation_is_rejected(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        value["generation"] = True
        with self.assertRaisesRegex(ValueError, "generation must be between"):
            METADATA.validate_channel(value, now=None)

    def test_oversized_generation_is_rejected(self) -> None:
        release = release_fixture()
        value = channel_fixture(release, "d" * 64)
        value["generation"] = METADATA.MAX_GENERATION + 1
        with self.assertRaisesRegex(ValueError, "generation must be between"):
            METADATA.validate_channel(value, now=None)


class ReleaseBindingTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)

    def files(self, *, prerelease: bool = False) -> tuple[Path, Path, Path]:
        release = release_fixture()
        release_path = self.root / "release.toml"
        write_release(release_path, release)
        channel = channel_fixture(release, hashlib.sha256(release_path.read_bytes()).hexdigest())
        channel_path = self.root / "channel.toml"
        write_channel(channel_path, channel)
        state_path = self.root / "release.json"
        state_path.write_text(
            json.dumps({"isDraft": False, "isPrerelease": prerelease, "tagName": "2026.1.0"}),
            encoding="utf-8",
        )
        return release_path, channel_path, state_path

    def verify(self, release: Path, channel: Path, state: Path, *, tag_commit: str = "a" * 40) -> dict[str, object]:
        args = argparse.Namespace(
            channel=channel,
            release=release,
            release_state=state,
            tag_commit=tag_commit,
            now="2026-07-17T00:00:00Z",
        )
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            METADATA.verify_release(args)
        return json.loads(output.getvalue())

    def test_verified_release_exports_authenticated_sha256(self) -> None:
        release, channel, state = self.files()
        result = self.verify(release, channel, state)
        self.assertEqual(result["targets"]["aarch64-apple-darwin"]["sha256"], f"{1:064x}")

    def test_release_metadata_digest_mismatch_is_rejected(self) -> None:
        release, channel, state = self.files()
        release.write_bytes(release.read_bytes() + b"\n")
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            self.verify(release, channel, state)

    def test_prerelease_is_rejected(self) -> None:
        release, channel, state = self.files(prerelease=True)
        with self.assertRaisesRegex(ValueError, "must not be a prerelease"):
            self.verify(release, channel, state)

    def test_draft_is_rejected(self) -> None:
        release, channel, state = self.files()
        state.write_text(
            json.dumps({"isDraft": True, "isPrerelease": False, "tagName": "2026.1.0"}),
            encoding="utf-8",
        )
        with self.assertRaisesRegex(ValueError, "must not be a draft"):
            self.verify(release, channel, state)

    def test_target_table_mismatch_is_rejected(self) -> None:
        release, channel, state = self.files()
        channel_value = METADATA.load_toml(channel)
        channel_value["targets"]["aarch64-apple-darwin"]["sha256"] = "f" * 64
        write_channel(channel, channel_value)
        with self.assertRaisesRegex(ValueError, "target tables"):
            self.verify(release, channel, state)

    def test_source_commit_must_match_release_tag(self) -> None:
        release, channel, state = self.files()
        with self.assertRaisesRegex(ValueError, "tag commit"):
            self.verify(release, channel, state, tag_commit="f" * 40)

    def test_false_readiness_gate_is_rejected(self) -> None:
        release, _, state = self.files()
        value = METADATA.load_toml(release)
        value["gates"]["release-ready"] = False
        write_release(release, value)
        channel_value = channel_fixture(value, hashlib.sha256(release.read_bytes()).hexdigest())
        channel = self.root / "unready-channel.toml"
        write_channel(channel, channel_value)
        with self.assertRaisesRegex(ValueError, "release-ready gate is false"):
            self.verify(release, channel, state)


if __name__ == "__main__":
    unittest.main()
