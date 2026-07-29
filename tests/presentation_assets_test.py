#!/usr/bin/env python3
"""Check the committed presentation exports without third-party image modules."""

from __future__ import annotations

import struct
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as image:
        signature = image.read(8)
        length, chunk_type = struct.unpack(">I4s", image.read(8))
        if signature != PNG_SIGNATURE or chunk_type != b"IHDR" or length != 13:
            raise AssertionError(f"{path} does not start with a valid PNG IHDR")
        return struct.unpack(">II", image.read(8))


def main() -> None:
    expected = {
        ROOT / "media/hero.png": (1300, 372),
        ROOT / "media/presentation/01-direct-hotkeys.png": (2560, 1440),
        ROOT / "media/presentation/02-live-status.png": (2560, 1440),
        ROOT / "media/presentation/03-exact-items.png": (2560, 1440),
        ROOT / "media/presentation/04-options.png": (2560, 1440),
        ROOT / "media/presentation/05-quick-keys.png": (2560, 1440),
        ROOT / "media/presentation/06-choose-slot.png": (2560, 1440),
        ROOT / "media/presentation/07-inventory-selector.png": (2560, 1440),
        ROOT / "media/presentation/08-magic-selector.png": (2560, 1440),
        ROOT / "media/presentation/09-script-settings.png": (2560, 1440),
    }

    for image, dimensions in expected.items():
        assert image.is_file(), f"missing presentation export: {image}"
        assert png_dimensions(image) == dimensions, (
            f"{image} must be {dimensions[0]}x{dimensions[1]}"
        )

    print("presentation_assets_test: ok")


if __name__ == "__main__":
    main()
