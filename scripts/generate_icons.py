"""Generate Aurora OS icons (PNG) from the Aurora-Pulse logo design.

The design mirrors `game/icon.svg`: a dark rounded square with three
overlapping mahjong tiles (cyan / yellow / red) in the centre.

Output sizes (Aurora OS / Sailfish OS launcher icon set):
    86x86    - mdpi
    108x108  - hdpi
    128x128  - xhdpi
    172x172  - xxhdpi

Run:
    python scripts/generate_icons.py
"""

from __future__ import annotations

import os
from pathlib import Path

from PIL import Image, ImageDraw

# Reference design at 128 px ----------------------------------------------------
REF = 128
BG_COLOR = (0x1A, 0x2A, 0x3A, 0xFF)
BG_RADIUS = 16  # rounded corners for the background

# (x, y, w, h, rx, color) — same proportions as game/icon.svg
TILES = [
    (24, 32, 32, 44, 4, (0x4E, 0xCD, 0xC4, 0xFF)),  # cyan, back-left
    (48, 48, 32, 44, 4, (0xFF, 0xE6, 0x6D, 0xFF)),  # yellow, front-center
    (72, 32, 32, 44, 4, (0xFF, 0x6B, 0x6B, 0xFF)),  # red, back-right
]

SIZES = [86, 108, 128, 172]

OUT_DIR = Path(__file__).resolve().parent.parent / "icons"


def _scale(value: float, size: int) -> float:
    return value * size / REF


def render_icon(size: int) -> Image.Image:
    """Render the icon at `size`x`size` pixels with anti-aliasing.

    We draw at 4x the target size and downsample for crisp rounded corners
    at small icon sizes (especially 86 px).
    """

    ss = 4  # supersampling factor
    big = size * ss
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    bg_radius = max(1, int(round(_scale(BG_RADIUS, big))))
    draw.rounded_rectangle(
        [(0, 0), (big - 1, big - 1)],
        radius=bg_radius,
        fill=BG_COLOR,
    )

    for x, y, w, h, rx, color in TILES:
        x0 = _scale(x, big)
        y0 = _scale(y, big)
        x1 = x0 + _scale(w, big)
        y1 = y0 + _scale(h, big)
        radius = max(1, int(round(_scale(rx, big))))
        draw.rounded_rectangle([(x0, y0), (x1, y1)], radius=radius, fill=color)

    return img.resize((size, size), Image.LANCZOS)


def main() -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for size in SIZES:
        out = OUT_DIR / f"icon-{size}.png"
        render_icon(size).save(out, format="PNG", optimize=True)
        print(f"  -> {out.relative_to(OUT_DIR.parent)} ({size}x{size})")


if __name__ == "__main__":
    main()
