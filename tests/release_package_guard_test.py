#!/usr/bin/env python3
"""Ensure development-only presentation tooling cannot enter release ZIPs."""

from __future__ import annotations

import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from package_release import (  # noqa: E402
    assert_release_names_allowed,
    collect_release_files,
    forbidden_release_names,
    load_config,
)


def main() -> None:
    safe_names = [
        "scripts/voshondsQuickSelect/presentation/icon_renderer.lua",
        "voshondsQuickSelect.omwscripts",
    ]
    unsafe_names = [
        "dev-content/presentation/settings.cfg",
        "scripts/voshondsQuickSelectPresentation/main.lua",
        ".presentation-runtime.ABC123/config/openmw.cfg",
        ".presentation-profile/config/player_storage.bin",
    ]

    assert forbidden_release_names(safe_names) == []
    assert forbidden_release_names(unsafe_names) == sorted(unsafe_names)

    try:
        assert_release_names_allowed(unsafe_names)
    except ValueError as error:
        assert "Development-only presentation files" in str(error)
    else:
        raise AssertionError("development presentation paths must be rejected")

    selected = [archive_name for _, archive_name in collect_release_files(load_config())]
    assert forbidden_release_names(selected) == []
    print("release_package_guard_test: ok")


if __name__ == "__main__":
    main()
