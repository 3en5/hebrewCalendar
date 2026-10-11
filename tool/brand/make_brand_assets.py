#!/usr/bin/env python3
"""Renders the app's brand assets from code.

Design (owner-approved KALFAPP rebrand, 2026-10-11): the same family as the
owner's other KALFAPP app (PowerWatch) — a light-blue line-art house and gear
plus the product's own symbol, here a calendar page with the letter "א".
The store feature graphic is white with the KALFAPP logo, like PowerWatch's.
`tool/brand/icon.svg` is a reference drawing of the same icon.

Outputs, relative to the repo root:
- android/app/src/main/res/mipmap-*/ic_launcher.png      legacy launcher icons
- android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive fg
- android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml     adaptive icon
- android/app/src/main/res/values/ic_launcher_background.xml     bg colour
- distribution/listings/images/icon.png                  Play icon, 512x512
- distribution/listings/images/featureGraphic.png        Play feature graphic

Fonts: Rubik (OFL, assets/fonts). Logo: assets/brand/kalfapp_logo.png.
Run from the repo root: python3 tool/brand/make_brand_assets.py
"""

import math
import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT_BOLD = os.path.join(ROOT, "assets/fonts/Rubik-Bold.ttf")
FONT_REGULAR = os.path.join(ROOT, "assets/fonts/Rubik-Regular.ttf")
LOGO = os.path.join(ROOT, "assets/brand/kalfapp_logo.png")
RES = os.path.join(ROOT, "android/app/src/main/res")
STORE = os.path.join(ROOT, "distribution/listings/images")

LINE = (75, 184, 245)          # PowerWatch's light-blue line colour
WHITE = (255, 255, 255)
GRAD_FROM = (15, 143, 224)     # KALFAPP logo gradient, blue → cyan
GRAD_TO = (24, 185, 201)
INK = (59, 74, 92)
MUTED = (122, 135, 150)

# Launcher icon sizes (48dp legacy, 108dp adaptive layer) per density.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}

SUPERSAMPLE = 4


def glyph(size):
    """The line-art icon on a transparent size x size canvas (1024 design grid)."""
    s = 1024 * SUPERSAMPLE
    k = SUPERSAMPLE
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = 34 * k

    def p(*pts):
        return [(x * k, y * k) for x, y in pts]

    # House: roof, wall and floor, window with its cross.
    d.line(p((440, 740), (110, 740), (110, 370), (60, 370), (355, 75), (560, 280)),
           fill=LINE, width=w, joint="curve")
    d.rounded_rectangle([215 * k, 390 * k, 415 * k, 590 * k], radius=14 * k,
                        outline=LINE, width=w)
    d.line(p((315, 390), (315, 590)), fill=LINE, width=w)
    d.line(p((215, 490), (415, 490)), fill=LINE, width=w)
    # Calendar page with binding rings and "א".
    d.rounded_rectangle([560 * k, 200 * k, 960 * k, 590 * k], radius=40 * k,
                        outline=LINE, width=w)
    d.line(p((560, 300), (960, 300)), fill=LINE, width=w)
    for x in (665, 855):
        d.line(p((x, 150), (x, 240)), fill=LINE, width=w)
    d.text((760 * k, 550 * k), "א", font=ImageFont.truetype(FONT_BOLD, 240 * k),
           fill=LINE, anchor="ms", direction="rtl")
    # Gear: eight teeth around a hole, overlapping the house's corner.
    cx, cy, outer, inner, teeth = 640, 735, 158, 122, 8
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * (i - 0.5) / (teeth * 4)
        r = outer if i % 4 in (0, 1) else inner
        pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    d.line(p(*pts, pts[0]), fill=LINE, width=w, joint="curve")
    d.ellipse([(cx - 62) * k, (cy - 62) * k, (cx + 62) * k, (cy + 62) * k],
              outline=LINE, width=w)
    return im.resize((size, size), Image.LANCZOS)


def tile(size, glyph_scale, corner=0.0):
    """The glyph centred on a white (optionally rounded) square."""
    im = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    d.rounded_rectangle([0, 0, size - 1, size - 1], radius=int(size * corner), fill=WHITE)
    g = glyph(int(size * glyph_scale))
    off = (size - g.width) // 2
    im.paste(g, (off, off), g)
    return im


def write(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def launcher_icons():
    master = tile(1024, 0.82, corner=0.22)
    for name, scale in DENSITIES.items():
        legacy = int(48 * scale)
        write(f"{RES}/mipmap-{name}/ic_launcher.png",
              master.resize((legacy, legacy), Image.LANCZOS))
        # Adaptive foreground: 108dp canvas, glyph inside the 66dp safe zone.
        layer = int(108 * scale)
        g = glyph(int(layer * 62 / 108))
        fg = Image.new("RGBA", (layer, layer), (0, 0, 0, 0))
        off = (layer - g.width) // 2
        fg.paste(g, (off, off), g)
        write(f"{RES}/mipmap-{name}/ic_launcher_foreground.png", fg)
    os.makedirs(f"{RES}/mipmap-anydpi-v26", exist_ok=True)
    with open(f"{RES}/mipmap-anydpi-v26/ic_launcher.xml", "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n'
                '<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">\n'
                '    <background android:drawable="@color/ic_launcher_background" />\n'
                '    <foreground android:drawable="@mipmap/ic_launcher_foreground" />\n'
                '</adaptive-icon>\n')
    with open(f"{RES}/values/ic_launcher_background.xml", "w") as f:
        f.write('<?xml version="1.0" encoding="utf-8"?>\n<resources>\n'
                '    <color name="ic_launcher_background">#FFFFFF</color>\n</resources>\n')


def gradient_text(canvas, xy, text, font):
    """Draws right-anchored RTL [text] filled with the KALFAPP gradient."""
    mask = Image.new("L", canvas.size, 0)
    ImageDraw.Draw(mask).text(xy, text, font=font, fill=255, anchor="rm", direction="rtl")
    box = mask.getbbox()
    fill = Image.new("RGB", canvas.size, WHITE)
    fd = ImageDraw.Draw(fill)
    for x in range(box[0], box[2]):
        t = (x - box[0]) / max(1, box[2] - box[0] - 1)
        fd.line([(x, 0), (x, canvas.height)],
                fill=tuple(int(GRAD_FROM[i] * (1 - t) + GRAD_TO[i] * t) for i in range(3)))
    canvas.paste(fill, (0, 0), mask)


def store_images():
    # Play masks the icon itself, so the store icon is a full-bleed square.
    write(f"{STORE}/icon.png", tile(512, 0.82).convert("RGB"))
    fg = Image.new("RGB", (1024, 500), WHITE)
    d = ImageDraw.Draw(fg)
    gradient_text(fg, (960, 190), "לוח עברי", ImageFont.truetype(FONT_BOLD, 108))
    d.text((960, 290), "היומן שבו התאריך העברי במרכז",
           font=ImageFont.truetype(FONT_REGULAR, 38), fill=INK, anchor="rm", direction="rtl")
    d.text((960, 350), "חגים ופרשה · אירועים חוזרים · סנכרון עם Google",
           font=ImageFont.truetype(FONT_REGULAR, 25), fill=MUTED, anchor="rm", direction="rtl")
    logo = Image.open(LOGO).convert("RGBA")
    logo = logo.resize((340, int(340 * logo.height / logo.width)), Image.LANCZOS)
    fg.paste(logo, (50, (500 - logo.height) // 2), logo)
    write(f"{STORE}/featureGraphic.png", fg)


if __name__ == "__main__":
    launcher_icons()
    store_images()
    print("brand assets written")
