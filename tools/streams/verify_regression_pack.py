#!/usr/bin/env python3
"""Verify the complete external MiSTer hardware regression pack."""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[2]
DOCS = REPO_ROOT / "docs"
MANIFEST_NAME = "compatibility_manifest.json"
CASE_FILES = {
    "multi_slice": "08_compat_multi_slice.m2v",
    "dense_residual": "09_compat_dense_residual.m2v",
    "mixed_macroblocks": "10_compat_mixed_macroblocks.m2v",
    "long_gop": "11_compat_long_gop.m2v",
}
LEGACY_REPO_PREFIX = "/run/media/vash/GIT/MiSTer-Media-Player/"
LEGACY_MANIFEST_SHA256 = "2934671cef979f15641d421c1fc2d58a714662642090d15b2d37c131b61acfd8"


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def load_checksums(path: Path) -> dict[str, str]:
    checksums: dict[str, str] = {}
    pattern = re.compile(r"^([0-9a-f]{64})  ([^/]+)$")
    for line_number, line in enumerate(path.read_text().splitlines(), 1):
        match = pattern.fullmatch(line)
        if match is None:
            raise ValueError(f"{path}:{line_number}: malformed checksum line")
        checksum, name = match.groups()
        if name in checksums:
            raise ValueError(f"{path}:{line_number}: duplicate filename {name}")
        checksums[name] = checksum
    return checksums


def walk_strings(value: Any):
    if isinstance(value, str):
        yield value
    elif isinstance(value, list):
        for item in value:
            yield from walk_strings(item)
    elif isinstance(value, dict):
        for item in value.values():
            yield from walk_strings(item)


def normalize_legacy_manifest(payload: bytes) -> bytes:
    text = payload.decode("utf-8")
    text = text.replace(LEGACY_REPO_PREFIX, "")
    text = text.replace('"/usr/bin/ffmpeg"', '"ffmpeg"')
    return text.encode("utf-8")


def validate_manifest(manifest_path: Path, checksums: dict[str, str]) -> None:
    document = json.loads(manifest_path.read_text())
    if document.get("authoritative_v0.5_matrix_replaced") is not False:
        raise ValueError("manifest must preserve the authoritative v0.5 matrix")
    cases = document.get("cases")
    if not isinstance(cases, list) or [case.get("name") for case in cases] != list(CASE_FILES):
        raise ValueError("manifest compatibility cases or ordering are incorrect")

    absolute = sorted({value for value in walk_strings(document) if value.startswith("/")})
    if absolute:
        raise ValueError(f"manifest contains absolute paths: {absolute}")

    for case in cases:
        name = case["name"]
        filename = CASE_FILES[name]
        analysis = case.get("analysis", {})
        if Path(str(analysis.get("path", ""))).name != "test_compat_" + name + ".m2v":
            raise ValueError(f"manifest path mismatch for {name}")
        if analysis.get("sha256") != checksums[filename]:
            raise ValueError(f"manifest stream digest mismatch for {name}")
        if not isinstance(analysis.get("bytes"), int) or analysis["bytes"] <= 0:
            raise ValueError(f"manifest byte count missing for {name}")
        if not isinstance(analysis.get("picture_count"), int) or analysis["picture_count"] <= 0:
            raise ValueError(f"manifest picture count missing for {name}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pack_dir", type=Path, help="directory containing the numbered .m2v files")
    args = parser.parse_args()
    pack_dir = args.pack_dir.resolve()
    if not pack_dir.is_dir():
        parser.error(f"pack directory not found: {pack_dir}")

    try:
        checksums = load_checksums(DOCS / "SHA256SUMS")
        expected_streams = set(checksums) - {MANIFEST_NAME}
        actual_streams = {path.name for path in pack_dir.glob("*.m2v")}
        if actual_streams != expected_streams:
            missing = sorted(expected_streams - actual_streams)
            unexpected = sorted(actual_streams - expected_streams)
            raise ValueError(f"stream file set mismatch; missing={missing}, unexpected={unexpected}")

        for name in sorted(expected_streams):
            actual = digest(pack_dir / name)
            if actual != checksums[name]:
                raise ValueError(f"{name}: expected {checksums[name]}, got {actual}")
            print(f"PASS stream   {name}")

        canonical_manifest = DOCS / MANIFEST_NAME
        actual = digest(canonical_manifest)
        if actual != checksums[MANIFEST_NAME]:
            raise ValueError(
                f"committed manifest: expected {checksums[MANIFEST_NAME]}, got {actual}"
            )
        validate_manifest(canonical_manifest, checksums)
        print(f"PASS manifest {MANIFEST_NAME}")

        pack_manifest = pack_dir / MANIFEST_NAME
        if not pack_manifest.is_file():
            raise ValueError(f"pack is missing {MANIFEST_NAME}")
        normalized = normalize_legacy_manifest(pack_manifest.read_bytes())
        if normalized == canonical_manifest.read_bytes():
            print("PASS pack manifest normalization")
        elif digest(pack_manifest) == LEGACY_MANIFEST_SHA256:
            print("PASS known v0.6.0-RC manifest (superseded debug inventory)")
        else:
            raise ValueError(
                "pack manifest is neither canonical nor the exact known v0.6.0-RC manifest"
            )
    except (OSError, UnicodeError, ValueError, json.JSONDecodeError) as error:
        print(f"FAIL: {error}", file=sys.stderr)
        return 1

    print(f"PASS: {len(expected_streams)} streams and canonical manifest verified")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
