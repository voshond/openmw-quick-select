#!/usr/bin/env python3
"""Create the release ZIP from config.json's explicit packaging manifest."""

from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
from pathlib import Path
from typing import Iterable


ROOT = Path(__file__).resolve().parents[1]
RELEASE_VERSION_PATTERN = re.compile(r"^\d+\.\d+\.\d+$")
ARTIFACT_VERSION_PATTERN = re.compile(r"^dev-[0-9a-f]{7,40}$")
DEV_ONLY_RELEASE_MARKERS = (
    "dev-content/",
    "voshondsquickselectpresentation",
    ".presentation-runtime",
    ".presentation-profile",
)


def load_config() -> dict:
    with (ROOT / "config.json").open(encoding="utf-8") as config_file:
        return json.load(config_file)


def validate_version(version: str) -> str:
    if not (RELEASE_VERSION_PATTERN.fullmatch(version) or ARTIFACT_VERSION_PATTERN.fullmatch(version)):
        raise ValueError(f"Version must use x.y.z or dev-<commit> format, got {version!r}")
    return version


def release_archive_name(config: dict, version: str) -> str:
    project_name = config["project"]["name"]
    if not project_name or any(character in project_name for character in "/\\"):
        raise ValueError("config.json project.name must be a non-empty file name")
    return f"{project_name}-v{version}.zip"


def source_path(manifest_path: str) -> Path:
    relative_path = Path(manifest_path)
    if relative_path.is_absolute() or ".." in relative_path.parts:
        raise ValueError(f"Packaging manifest entry must be a relative project path: {manifest_path}")
    return ROOT / relative_path


def build_info_archive_name(config: dict) -> str:
    generated = config.get("packaging", {}).get("generated", {})
    manifest_path = generated.get("buildInfo") if isinstance(generated, dict) else None
    if not isinstance(manifest_path, str):
        raise ValueError("config.json packaging.generated.buildInfo must be a relative path")
    return source_path(manifest_path).relative_to(ROOT).as_posix()


def render_build_info(version: str) -> str:
    label = f"Version {version}" if RELEASE_VERSION_PATTERN.fullmatch(version) else f"Development build {version}"
    return (
        "-- Generated during packaging. Do not edit.\n"
        "return {\n"
        f'    version = "{version}",\n'
        f'    label = "{label}",\n'
        "}\n"
    )


def forbidden_release_names(archive_names: Iterable[str]) -> list[str]:
    """Return paths that identify the development-only presentation tooling."""
    forbidden = []
    for archive_name in archive_names:
        normalized = archive_name.replace("\\", "/").lower()
        if any(marker in normalized for marker in DEV_ONLY_RELEASE_MARKERS):
            forbidden.append(archive_name)
    return sorted(forbidden)


def assert_release_names_allowed(archive_names: Iterable[str]) -> None:
    forbidden = forbidden_release_names(archive_names)
    if forbidden:
        raise ValueError(
            "Development-only presentation files cannot be packaged: "
            + ", ".join(forbidden)
        )


def collect_release_files(config: dict) -> list[tuple[Path, str]]:
    includes = config.get("packaging", {}).get("includes")
    if not isinstance(includes, list) or not includes:
        raise ValueError("config.json packaging.includes must contain at least one path")

    files: list[tuple[Path, str]] = []
    archive_names: set[str] = set()
    for manifest_path in includes:
        if not isinstance(manifest_path, str):
            raise ValueError("Packaging manifest entries must be strings")

        source = source_path(manifest_path)
        if not source.exists():
            raise FileNotFoundError(f"Packaging manifest entry does not exist: {manifest_path}")

        candidates: Iterable[Path]
        if source.is_dir():
            candidates = sorted(path for path in source.rglob("*") if path.is_file())
        elif source.is_file():
            candidates = [source]
        else:
            raise ValueError(f"Packaging manifest entry is not a regular file or directory: {manifest_path}")

        for candidate in candidates:
            archive_name = candidate.relative_to(ROOT).as_posix()
            if archive_name in archive_names:
                raise ValueError(f"Packaging manifest includes {archive_name} more than once")
            archive_names.add(archive_name)
            files.append((candidate, archive_name))

    if not files:
        raise ValueError("Packaging manifest did not select any files")
    assert_release_names_allowed(archive_name for _, archive_name in files)
    return sorted(files, key=lambda entry: entry[1])


def expected_archive_names(config: dict) -> list[str]:
    archive_names = [archive_name for _, archive_name in collect_release_files(config)]
    generated_build_info = build_info_archive_name(config)
    if generated_build_info in archive_names:
        raise ValueError(
            f"Generated build info conflicts with a source file: {generated_build_info}"
        )
    expected = sorted([*archive_names, generated_build_info])
    assert_release_names_allowed(expected)
    return expected


def resolve_output_directory(value: str) -> Path:
    output_directory = Path(value)
    return output_directory if output_directory.is_absolute() else ROOT / output_directory


def build_archive(version: str, output_directory: Path) -> Path:
    config = load_config()
    archive_path = output_directory / release_archive_name(config, version)
    temporary_archive_path = archive_path.with_name(f".{archive_path.name}.tmp")
    release_files = collect_release_files(config)
    generated_build_info = build_info_archive_name(config)
    source_files = {archive_name: source for source, archive_name in release_files}
    archive_names = expected_archive_names(config)

    output_directory.mkdir(parents=True, exist_ok=True)
    try:
        with zipfile.ZipFile(
            temporary_archive_path,
            mode="w",
            compression=zipfile.ZIP_DEFLATED,
            compresslevel=9,
        ) as archive:
            for archive_name in archive_names:
                if archive_name == generated_build_info:
                    archive.writestr(archive_name, render_build_info(version))
                else:
                    archive.write(source_files[archive_name], archive_name)
        temporary_archive_path.replace(archive_path)
    except OSError:
        temporary_archive_path.unlink(missing_ok=True)
        raise

    print(archive_path)
    print("Archive contents:")
    for archive_name in archive_names:
        print(f"  {archive_name}")
    return archive_path


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--version",
        help="Release x.y.z or CI artifact dev-<commit> version (defaults to config.json)",
    )
    parser.add_argument(
        "--output-dir",
        default="dist",
        help="Directory for the generated ZIP, relative to the repository root",
    )
    arguments = parser.parse_args()

    try:
        config = load_config()
        version = validate_version(arguments.version or config["project"]["version"])
        build_archive(version, resolve_output_directory(arguments.output_dir))
    except (KeyError, TypeError, ValueError, OSError, zipfile.BadZipFile) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
