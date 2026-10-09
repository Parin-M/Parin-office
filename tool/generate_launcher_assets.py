#!/usr/bin/env python3
"""Generate Parin Office launcher PNG assets using only the Python standard library."""
from __future__ import annotations

import math
import pathlib
import struct
import zlib

ROOT = pathlib.Path(__file__).resolve().parents[1] / "assets" / "branding"
SIZE = 1024


def chunk(kind: bytes, payload: bytes) -> bytes:
    body = kind + payload
    return struct.pack(">I", len(payload)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)


def save_png(path: pathlib.Path, width: int, height: int, pixels: bytearray) -> None:
    rows = bytearray()
    stride = width * 4
    for y in range(height):
        rows.append(0)
        rows.extend(pixels[y * stride:(y + 1) * stride])
    header = struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0)
    data = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header) + chunk(b"IDAT", zlib.compress(bytes(rows), 9)) + chunk(b"IEND", b"")
    path.write_bytes(data)


def blend(canvas: bytearray, x: int, y: int, color: tuple[int, int, int, int]) -> None:
    if x < 0 or y < 0 or x >= SIZE or y >= SIZE:
        return
    at = (y * SIZE + x) * 4
    alpha = color[3]
    if alpha >= 255:
        canvas[at:at + 4] = bytes(color)
        return
    if alpha <= 0:
        return
    old = canvas[at:at + 4]
    inv = 255 - alpha
    out_a = alpha + old[3] * inv // 255
    if out_a == 0:
        canvas[at:at + 4] = b"\x00\x00\x00\x00"
        return
    for i in range(3):
        canvas[at + i] = (color[i] * alpha + old[i] * old[3] * inv // 255) // out_a
    canvas[at + 3] = out_a


def rounded_rect(canvas: bytearray, x: int, y: int, w: int, h: int, r: int,
                 color: tuple[int, int, int, int]) -> None:
    x0, y0, x1, y1 = max(0, x), max(0, y), min(SIZE, x + w), min(SIZE, y + h)
    for py in range(y0, y1):
        cy = min(max(py + 0.5, y + r), y + h - r)
        for px in range(x0, x1):
            cx = min(max(px + 0.5, x + r), x + w - r)
            if (px + 0.5 - cx) ** 2 + (py + 0.5 - cy) ** 2 <= r * r:
                blend(canvas, px, py, color)


def polygon(canvas: bytearray, points: list[tuple[int, int]], color: tuple[int, int, int, int]) -> None:
    min_x = max(0, min(p[0] for p in points))
    max_x = min(SIZE - 1, max(p[0] for p in points))
    min_y = max(0, min(p[1] for p in points))
    max_y = min(SIZE - 1, max(p[1] for p in points))
    for y in range(min_y, max_y + 1):
        for x in range(min_x, max_x + 1):
            inside = False
            j = len(points) - 1
            for i in range(len(points)):
                xi, yi = points[i]
                xj, yj = points[j]
                if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / ((yj - yi) or 1) + xi):
                    inside = not inside
                j = i
            if inside:
                blend(canvas, x, y, color)


def erase_rect(canvas: bytearray, x: int, y: int, w: int, h: int) -> None:
    """Clear a transparent cut-out; used to make a true monochrome glyph."""
    x0, y0, x1, y1 = max(0, x), max(0, y), min(SIZE, x + w), min(SIZE, y + h)
    for py in range(y0, y1):
        start = (py * SIZE + x0) * 4
        end = (py * SIZE + x1) * 4
        canvas[start:end] = bytes(end - start)


def paint_mark(canvas: bytearray, foreground: bool = False, monochrome: bool = False) -> None:
    white = (255, 255, 255, 255)
    blue = (42, 103, 244, 255)
    muted = (200, 211, 232, 255)
    mint = (98, 232, 211, 255)
    if foreground and monochrome:
        # Android 13+ themed icons discard RGB and tint opaque pixels with the
        # launcher palette. Use one thick, centered P glyph on transparency;
        # do not reuse the colored "page" foreground for Material You.
        # The complete symbol stays inside the adaptive icon's center safe area.
        rounded_rect(canvas, 290, 220, 115, 580, 38, white)
        rounded_rect(canvas, 340, 220, 385, 115, 38, white)
        rounded_rect(canvas, 620, 255, 105, 255, 36, white)
        rounded_rect(canvas, 355, 405, 370, 105, 34, white)
        # Cut the bowl out of the P while keeping an opaque, single-color silhouette.
        erase_rect(canvas, 405, 335, 215, 70)
        return
    if foreground:
        # Keep the full artwork within Android's centered 66% safe zone.
        rounded_rect(canvas, 270, 190, 484, 644, 58, white)
        polygon(canvas, [(605, 190), (754, 339), (605, 339)], (221, 232, 255, 255))
        rounded_rect(canvas, 340, 390, 68, 220, 20, blue)
        rounded_rect(canvas, 340, 390, 240, 60, 20, blue)
        rounded_rect(canvas, 340, 475, 205, 56, 20, blue)
        rounded_rect(canvas, 515, 430, 65, 85, 18, blue)
        rounded_rect(canvas, 414, 445, 100, 28, 9, white)
        rounded_rect(canvas, 340, 650, 230, 14, 7, muted)
        rounded_rect(canvas, 340, 692, 280, 14, 7, muted)
        rounded_rect(canvas, 340, 734, 180, 14, 7, muted)
        rounded_rect(canvas, 610, 746, 80, 80, 22, mint)
    else:
        rounded_rect(canvas, 230, 140, 564, 744, 72, white)
        polygon(canvas, [(600, 140), (794, 334), (600, 334)], (226, 236, 255, 255))
        rounded_rect(canvas, 306, 368, 276, 44, 22, blue)
        rounded_rect(canvas, 306, 464, 68, 244, 20, blue)
        rounded_rect(canvas, 306, 464, 275, 62, 22, blue)
        rounded_rect(canvas, 306, 556, 220, 60, 22, blue)
        rounded_rect(canvas, 520, 495, 61, 75, 18, blue)
        rounded_rect(canvas, 382, 526, 134, 32, 9, white)
        rounded_rect(canvas, 306, 730, 306, 15, 7, muted)
        rounded_rect(canvas, 306, 772, 354, 15, 7, muted)
        rounded_rect(canvas, 306, 814, 218, 15, 7, muted)
        rounded_rect(canvas, 655, 760, 82, 82, 22, mint)


def main() -> None:
    ROOT.mkdir(parents=True, exist_ok=True)

    background = bytearray(SIZE * SIZE * 4)
    top = (17, 28, 65)
    bottom = (73, 53, 164)
    for y in range(SIZE):
        ty = y / (SIZE - 1)
        for x in range(SIZE):
            tx = x / (SIZE - 1)
            glow = max(0.0, 1.0 - math.sqrt(((tx - 0.78) * 1.0) ** 2 + ((ty - 0.16) * 1.15) ** 2))
            color = tuple(int(top[k] * (1 - ty) + bottom[k] * ty + [12, 8, 26][k] * glow) for k in range(3))
            at = (y * SIZE + x) * 4
            background[at:at + 4] = bytes((*[min(255, c) for c in color], 255))
    paint_mark(background)
    save_png(ROOT / "parin_icon.png", SIZE, SIZE, background)

    foreground = bytearray(SIZE * SIZE * 4)
    paint_mark(foreground, foreground=True)
    save_png(ROOT / "parin_icon_foreground.png", SIZE, SIZE, foreground)

    monochrome = bytearray(SIZE * SIZE * 4)
    paint_mark(monochrome, foreground=True, monochrome=True)
    save_png(ROOT / "parin_icon_monochrome.png", SIZE, SIZE, monochrome)


if __name__ == "__main__":
    main()
