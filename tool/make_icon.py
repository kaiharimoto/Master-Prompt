#!/usr/bin/env python3
"""Generates the app icon for Windows and Android.

Committed alongside the icons it produces, so the mark is reproducible rather
than a binary nobody can regenerate — the same reason the fonts carry their
licence and the keystore carries a note about what it may not sign.

    pip install Pillow && python3 tool/make_icon.py

The app shipped the stock Flutter template icon on both platforms until this
existed. The mark is deliberately plain: the wordmark's initial in the app's
own type and ink, over the hairline rule the whole design system is built on.

**The letter is P, and Master Idea's is I.** The two are one family and look
it — same ink, same type, same rule — so the initial is the only thing telling
them apart in a taskbar or a launcher, and it has to be the one thing that
differs. It was M for both, which made two identical icons.
"""
from PIL import Image, ImageDraw, ImageFont

INK = (0x17, 0x18, 0x1A, 255)      # MpColors.light.ink
CANVAS = (0xFB, 0xFB, 0xFA, 255)   # MpColors.light.canvas
FONT = 'packages/mp_design/assets/fonts/Inter-SemiBold.ttf'

# The half of the pair this is. Master Idea draws the same mark with an I.
LETTER = 'P'

ICO = 'app/windows/runner/resources/app_icon.ico'
ICO_SIZES = [16, 24, 32, 48, 64, 128, 256]
MIPMAPS = [('mdpi', 48), ('hdpi', 72), ('xhdpi', 96),
           ('xxhdpi', 144), ('xxxhdpi', 192)]


def mark(px, *, squircle=True):
    """Draws the mark at 4x and downsamples.

    A glyph scaled down from one large render keeps its weight; one rasterised
    straight to 16px loses it and reads as a grey smudge in the taskbar.
    """
    S = px * 4
    im = Image.new('RGBA', (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)

    if squircle:
        d.rounded_rectangle([0, 0, S - 1, S - 1], radius=int(S * 0.22), fill=INK)
    else:
        # Full bleed: the Android launcher applies its own mask over this.
        d.rectangle([0, 0, S - 1, S - 1], fill=INK)

    f = ImageFont.truetype(FONT, int(S * 0.56))
    box = d.textbbox((0, 0), LETTER, font=f)
    w, h = box[2] - box[0], box[3] - box[1]

    rw, rh = int(S * 0.30), max(1, int(S * 0.045))
    gap = S * 0.10

    # Centre the letter and the rule together as one group. Centring the
    # letter alone leaves the rule hanging off the bottom and the mark reads
    # high in its square.
    top = (S - (h + gap + rh)) / 2

    # Type is placed from its bounding box, never from the em, or it sits low
    # and to the left of where it looks centred.
    d.text((S / 2 - w / 2 - box[0], top - box[1]), LETTER, font=f, fill=CANVAS)
    ry = top + h + gap
    d.rounded_rectangle([S / 2 - rw / 2, ry, S / 2 + rw / 2, ry + rh],
                        radius=rh // 2, fill=CANVAS)
    return im.resize((px, px), Image.LANCZOS)


if __name__ == '__main__':
    mark(256).save(ICO, sizes=[(s, s) for s in ICO_SIZES])
    print(f'wrote {ICO} ({len(ICO_SIZES)} sizes)')
    for name, px in MIPMAPS:
        path = f'app/android/app/src/main/res/mipmap-{name}/ic_launcher.png'
        mark(px, squircle=False).convert('RGB').save(path)
        print(f'wrote {path} ({px}px)')
