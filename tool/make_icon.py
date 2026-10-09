#!/usr/bin/env python3
"""Draws the launcher icons for Windows and Android from the mark.

Committed alongside the icons it produces, so the mark is reproducible rather
than a binary nobody can regenerate.


The mark is defined once, in `MpMarkPainter` (packages/mp_design); these
coordinates are a copy of it on the same 100-unit grid. Exported icons are
always the light version — paper on an ink square — because a launcher icon
does not follow the app's theme (master-ui/guides/MARK.md §7).

    pip install Pillow && python3 tool/make_icon.py    # from the repo root

Rendered at 1024 and scaled down, so the 45-degree edges stay clean at 16px.

The previous mark was the wordmark's initial on a rounded square. Master UI
forbids both: a mark draws what the app acts on, never a letter, and nothing
in the family is rounded.
"""

from PIL import Image, ImageDraw

INK = (0, 0, 0, 255)
PAPER = (255, 255, 255, 255)

# Must match MpMarkPainter.caret and MpMarkPainter.line.
CARET = [(16, 22), (32, 22), (58, 48), (32, 74), (16, 74), (42, 48)]
LINE = (60, 62, 24, 12)  # x, y, w, h


def mark(size: int) -> Image.Image:
    big = 1024
    k = big / 100
    im = Image.new("RGBA", (big, big), INK)
    d = ImageDraw.Draw(im)
    d.polygon([(x * k, y * k) for x, y in CARET], fill=PAPER)
    x, y, w, h = LINE
    d.rectangle([x * k, y * k, (x + w) * k - 1, (y + h) * k - 1], fill=PAPER)
    return im.resize((size, size), Image.LANCZOS)


ANDROID = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
RES = "app/android/app/src/main/res"

for density, px in ANDROID.items():
    mark(px).save(f"{RES}/mipmap-{density}/ic_launcher.png")

mark(256).save(
    "app/windows/runner/resources/app_icon.ico",
    sizes=[(16, 16), (24, 24), (32, 32), (48, 48), (64, 64), (128, 128), (256, 256)],
)
print("icons written")
