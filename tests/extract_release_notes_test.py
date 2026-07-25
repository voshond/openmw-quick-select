#!/usr/bin/env python3
"""Regression checks for release-note output written to GITHUB_OUTPUT."""

from __future__ import annotations

import json
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "tools"))

from extract_release_notes import extract  # noqa: E402


def main() -> None:
    config = json.loads((ROOT / "config.json").read_text(encoding="utf-8"))
    version = config["project"]["version"]
    notes = extract(version, body_only=True)

    assert notes.endswith("\n"), "body-only release notes must end with a newline"
    github_output = f"nexus_description<<EOF\n{notes}EOF\n"
    assert github_output.endswith("\nEOF\n"), "GITHUB_OUTPUT delimiter must be on its own line"

    print("extract_release_notes_test: ok")


if __name__ == "__main__":
    main()
