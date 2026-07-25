#!/usr/bin/env python3
"""Verify that a release ZIP exactly matches config.json's packaging manifest."""

from __future__ import annotations

import argparse
import sys
import zipfile
from pathlib import Path

from package_release import (
    ROOT,
    build_info_archive_name,
    expected_archive_names,
    load_config,
    render_build_info,
    validate_version,
)


def resolve_archive(value: str) -> Path:
    archive = Path(value)
    return archive if archive.is_absolute() else ROOT / archive


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--archive", required=True, help="ZIP archive to inspect")
    parser.add_argument("--version", required=True, help="Version expected in generated build metadata")
    arguments = parser.parse_args()
    archive_path = resolve_archive(arguments.archive)

    try:
        config = load_config()
        version = validate_version(arguments.version)
        expected = expected_archive_names(config)
        with zipfile.ZipFile(archive_path) as archive:
            corrupt_file = archive.testzip()
            if corrupt_file:
                raise ValueError(f"Archive data is corrupt: {corrupt_file}")

            actual = [entry.filename for entry in archive.infolist()]
            build_info = archive.read(build_info_archive_name(config)).decode("utf-8")

        duplicates = sorted({name for name in actual if actual.count(name) > 1})
        missing = sorted(set(expected) - set(actual))
        unexpected = sorted(set(actual) - set(expected))
        if duplicates or missing or unexpected or actual != sorted(actual):
            problems: list[str] = []
            if duplicates:
                problems.append(f"duplicate entries: {', '.join(duplicates)}")
            if missing:
                problems.append(f"missing entries: {', '.join(missing)}")
            if unexpected:
                problems.append(f"unexpected entries: {', '.join(unexpected)}")
            if actual != sorted(actual):
                problems.append("archive entries are not sorted")
            raise ValueError("; ".join(problems))
        expected_build_info = render_build_info(version)
        if build_info != expected_build_info:
            raise ValueError("generated build info does not match the expected version")
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    print(f"Verified {archive_path}: {len(actual)} expected files")
    print("Verified contents:")
    for archive_name in actual:
        print(f"  {archive_name}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
