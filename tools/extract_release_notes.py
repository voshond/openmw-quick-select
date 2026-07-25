#!/usr/bin/env python3
"""Extract the newest changelog section for a tagged release."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
HEADING = re.compile(r"^## Version (?P<version>\d+\.\d+\.\d+) \([^\n]+\)$", re.MULTILINE)


def extract(version: str, body_only: bool) -> str:
    changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
    headings = list(HEADING.finditer(changelog))
    if not headings:
        raise ValueError("CHANGELOG.md does not contain any release headings")

    latest = headings[0]
    if latest.group("version") != version:
        raise ValueError(
            f"Newest CHANGELOG.md entry is {latest.group('version')}, not the tagged version {version}"
        )

    next_heading_start = headings[1].start() if len(headings) > 1 else len(changelog)
    body = changelog[latest.end() : next_heading_start].strip()
    if not body:
        raise ValueError(f"CHANGELOG.md entry for {version} has no release notes")

    return f"{body}\n" if body_only else f"{latest.group(0)}\n\n{body}\n"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True, help="Release version in x.y.z format")
    parser.add_argument("--output", help="File to write instead of standard output")
    parser.add_argument(
        "--body-only",
        action="store_true",
        help="Omit the changelog heading (for the Nexus file description)",
    )
    arguments = parser.parse_args()

    try:
        notes = extract(arguments.version, arguments.body_only)
    except (OSError, ValueError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 1

    if arguments.output:
        Path(arguments.output).write_text(notes, encoding="utf-8")
    else:
        print(notes, end="")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
