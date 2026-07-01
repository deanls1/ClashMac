#!/usr/bin/env python3
"""Generate Clash Mac app icon PNGs for AppIcon.appiconset and AppLogo.imageset."""

from __future__ import annotations

import math
import struct
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP_ICON_DIR = ROOT / "ClashMac/Resources/Assets.xcassets/AppIcon.appiconset"
LOGO_DIR = ROOT / "ClashMac/Resources/Assets.xcassets/AppLogo.imageset"

APP_ICON_SIZES = {
    "icon-16.png": 16,
    "icon-16@2x.png": 32,
    "icon-32.png": 32,
    "icon-32@2x.png": 64,
    "icon-128.png": 128,
    "icon-128@2x.png": 256,
    "icon-256.png": 256,
    "icon-256@2x.png": 512,
    "icon-512.png": 512,
    "icon-512@2x.png": 1024,
}

LOGO_SIZES = {
    "logo-128.png": 128,
    "logo-256.png": 256,
}


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def blend(c1: tuple[int, int, int], c2: tuple[int, int, int], t: float) -> tuple[int, int, int]:
    return (
        int(lerp(c1[0], c2[0], t)),
        int(lerp(c1[1], c2[1], t)),
        int(lerp(c1[2], c2[2], t)),
    )


def draw_icon(size: int) -> list[tuple[int, int, int, int]]:
    pixels: list[tuple[int, int, int, int]] = []
    top = (0x2E, 0x7D, 0xFF)
    bottom = (0x5B, 0x4D, 0xF0)
    corner = size * 0.22

    for y in range(size):
        for x in range(size):
            nx = x / max(size - 1, 1)
            ny = y / max(size - 1, 1)
            inside = (
                x >= corner
                and y >= corner
                and x <= size - 1 - corner
                and y <= size - 1 - corner
            ) or (
                math.hypot(max(corner - x, 0, x - (size - 1 - corner)), max(corner - y, 0, y - (size - 1 - corner)))
                <= corner
            )
            if not inside:
                pixels.append((0, 0, 0, 0))
                continue
            base = blend(top, bottom, ny)
            # subtle highlight
            highlight = max(0.0, 1.0 - math.hypot(nx - 0.28, ny - 0.22) * 1.8)
            color = (
                min(255, int(base[0] + 40 * highlight)),
                min(255, int(base[1] + 40 * highlight)),
                min(255, int(base[2] + 40 * highlight)),
            )
            pixels.append((*color, 255))

    # white "C" arc
    cx, cy = size * 0.5, size * 0.52
    outer = size * 0.24
    inner = size * 0.13
    for y in range(size):
        for x in range(size):
            idx = y * size + x
            if pixels[idx][3] == 0:
                continue
            dx, dy = x - cx, y - cy
            dist = math.hypot(dx, dy)
            angle = math.degrees(math.atan2(dy, dx))
            on_ring = inner <= dist <= outer and -130 <= angle <= 130
            if on_ring:
                pixels[idx] = (255, 255, 255, 255)
    return pixels


def write_png(path: Path, size: int, pixels: list[tuple[int, int, int, int]]) -> None:
    raw = bytearray()
    for y in range(size):
        raw.append(0)
        for x in range(size):
            r, g, b, a = pixels[y * size + x]
            raw.extend((r, g, b, a))

    def chunk(tag: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + tag + data + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    idat = zlib.compress(bytes(raw), 9)
    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(png)


def main() -> None:
    for filename, size in APP_ICON_SIZES.items():
        write_png(APP_ICON_DIR / filename, size, draw_icon(size))
    for filename, size in LOGO_SIZES.items():
        write_png(LOGO_DIR / filename, size, draw_icon(size))

    logo_contents = {
        "images": [
            {"idiom": "mac", "scale": "1x", "filename": "logo-128.png"},
            {"idiom": "mac", "scale": "2x", "filename": "logo-256.png"},
        ],
        "info": {"author": "xcode", "version": 1},
        "properties": {"template-rendering-intent": "original"},
    }
    import json

    LOGO_DIR.mkdir(parents=True, exist_ok=True)
    (LOGO_DIR / "Contents.json").write_text(json.dumps(logo_contents, indent=2) + "\n", encoding="utf-8")
    print(f"Generated {len(APP_ICON_SIZES)} app icons and {len(LOGO_SIZES)} logo images")


if __name__ == "__main__":
    main()
