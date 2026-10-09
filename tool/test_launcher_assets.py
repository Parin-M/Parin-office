#!/usr/bin/env python3
"""Validate Android adaptive and Material You launcher-icon assets."""
from __future__ import annotations

import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "branding"
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def read_rgba(path: pathlib.Path) -> tuple[int, int, list[bytes]]:
    data = path.read_bytes()
    assert data.startswith(PNG_SIGNATURE), f"{path.name} is not a PNG"
    offset = len(PNG_SIGNATURE)
    width = height = bit_depth = color_type = None
    compressed = bytearray()
    while offset < len(data):
        length = struct.unpack(">I", data[offset:offset + 4])[0]
        kind = data[offset + 4:offset + 8]
        payload = data[offset + 8:offset + 8 + length]
        offset += length + 12
        if kind == b"IHDR":
            width, height, bit_depth, color_type, compression, filtering, interlace = struct.unpack(">IIBBBBB", payload)
            assert (compression, filtering, interlace) == (0, 0, 0)
        elif kind == b"IDAT":
            compressed.extend(payload)
        elif kind == b"IEND":
            break
    assert width is not None and height is not None
    assert bit_depth == 8 and color_type == 6, f"{path.name} must be RGBA PNG"
    raw = zlib.decompress(compressed)
    stride = width * 4
    rows = []
    for y in range(height):
        start = y * (stride + 1)
        assert raw[start] == 0, "generator should use the deterministic PNG filter 0"
        rows.append(raw[start + 1:start + 1 + stride])
    return width, height, rows


def alpha_bounds(width: int, height: int, rows: list[bytes]) -> tuple[int, int, int, int, int]:
    xs: list[int] = []
    ys: list[int] = []
    visible = 0
    for y in range(height):
        row = rows[y]
        for x in range(width):
            at = x * 4
            r, g, b, a = row[at:at + 4]
            if a:
                xs.append(x)
                ys.append(y)
                visible += 1
    assert visible > 0, "icon layer must not be empty"
    return min(xs), min(ys), max(xs), max(ys), visible


def main() -> None:
    for name in ("parin_icon.png", "parin_icon_foreground.png", "parin_icon_monochrome.png"):
        assert (ROOT / name).is_file(), f"missing generated asset: {name}"

    full_w, full_h, full = read_rgba(ROOT / "parin_icon.png")
    fg_w, fg_h, fg = read_rgba(ROOT / "parin_icon_foreground.png")
    mono_w, mono_h, mono = read_rgba(ROOT / "parin_icon_monochrome.png")
    assert (full_w, full_h) == (1024, 1024)
    assert (fg_w, fg_h) == (1024, 1024)
    assert (mono_w, mono_h) == (1024, 1024)

    # Foreground art must stay inside Android's centered 66% safe zone.
    x0, y0, x1, y1, _ = alpha_bounds(fg_w, fg_h, fg)
    assert x0 >= 174 and y0 >= 174 and x1 < 850 and y1 < 850, (
        f"adaptive foreground escapes safe zone: {(x0, y0, x1, y1)}"
    )

    # Android 13+ recolors every non-transparent monochrome pixel with one
    # system tint. Non-white artwork or a solid filled page would hide the mark.
    mx0, my0, mx1, my1, visible = alpha_bounds(mono_w, mono_h, mono)
    assert mx0 >= 174 and my0 >= 174 and mx1 < 850 and my1 < 850
    assert visible >= 50_000, "monochrome glyph is too small"
    for row in mono:
        for x in range(mono_w):
            at = x * 4
            r, g, b, a = row[at:at + 4]
            if a:
                assert (r, g, b) == (255, 255, 255), "themed icon foreground must be pure white"
    # Confirm negative space exists around the glyph for launchers that tint it.
    assert mono[0][3] == 0 and mono[512][512 * 4 + 3] == 255 and mono[512][512 * 4] == 255
    print("Launcher icon validation passed: adaptive safe zone and monochrome tint layer are valid.")


if __name__ == "__main__":
    main()
