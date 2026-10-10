#!/usr/bin/env python3
"""Renders the app's brand assets from code (owner-approved design, 2026-10-10).

Outputs, relative to the repo root:
- android/app/src/main/res/mipmap-*/ic_launcher.png      legacy launcher icons
- android/app/src/main/res/mipmap-*/ic_launcher_foreground.png  adaptive fg
- android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml     adaptive icon
- android/app/src/main/res/values/ic_launcher_background.xml     bg colour
- distribution/listings/images/icon.png                  Play icon, 512x512
- distribution/listings/images/featureGraphic.png        Play feature graphic

Design: blue (#1A73E8, the app's seed colour) rounded square, white calendar
page with binding rings and the letter "א". Font: Heebo (OFL, tool/brand/fonts).
Run from the repo root: python3 tool/brand/make_brand_assets.py
"""

import os
from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
FONT = os.path.join(ROOT, "tool/brand/fonts/Heebo.ttf")
RES = os.path.join(ROOT, "android/app/src/main/res")
STORE = os.path.join(ROOT, "distribution/listings/images")

BLUE = (26, 115, 232)
DARK = (13, 71, 161)
WHITE = (255, 255, 255)
LIGHT = (232, 240, 254)

# Launcher icon sizes (48dp legacy, 108dp adaptive layer) per density.
DENSITIES = {"mdpi": 1, "hdpi": 1.5, "xhdpi": 2, "xxhdpi": 3, "xxxhdpi": 4}


def font(size, weight):
    f = ImageFont.truetype(FONT, size)
    f.set_variation_by_axes([weight])
    return f


def calendar(size, background, corner=0.22):
    """The calendar glyph on a size x size canvas, optionally on the blue tile."""
    s = size
    im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    if background:
        d.rounded_rectangle([0, 0, s - 1, s - 1], radius=int(s * corner), fill=BLUE)
    m, top, header = int(s * 0.18), int(s * 0.22), int(s * 0.16)
    d.rounded_rectangle([m, top, s - m, s - m], radius=int(s * 0.07), fill=WHITE)
    d.rounded_rectangle([m, top, s - m, top + header], radius=int(s * 0.07), fill=LIGHT)
    d.rectangle([m, top + int(s * 0.09), s - m, top + header], fill=LIGHT)
    ring_w, ring_h = int(s * 0.025), int(s * 0.06)
    for x in (0.36, 0.64):
        cx = int(s * x)
        d.rounded_rectangle([cx - ring_w, top - ring_h, cx + ring_w, top + ring_h],
                            radius=max(1, int(s * 0.02)), fill=DARK)
    body_mid = top + header + (s - m - top - header) / 2
    d.text((s / 2, body_mid), "א", font=font(int(s * 0.42), 800), fill=BLUE,
           anchor="mm", direction="rtl")
    return im


def write(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, optimize=True)


def launcher_icons():
    master = calendar(1024, background=True)
    for name, scale in DENSITIES.items():
        legacy = int(48 * scale)
        write(f"{RES}/mipmap-{name}/ic_launcher.png",
              master.resize((legacy, legacy), Image.LANCZOS))
        # Adaptive foreground: 108dp canvas, glyph inside the 66dp safe zone.
        layer = int(108 * scale)
        glyph = calendar(1024, background=False).resize(
            (int(layer * 72 / 108),) * 2, Image.LANCZOS)
        fg = Image.new("RGBA", (layer, layer), (0, 0, 0, 0))
        off = (layer - glyph.width) // 2
        fg.paste(glyph, (off, off), glyph)
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
                '    <color name="ic_launcher_background">#1A73E8</color>\n</resources>\n')


def store_images():
    # Play masks the icon itself, so the store icon is a full-bleed square.
    write(f"{STORE}/icon.png", calendar(512, background=True, corner=0))
    fg = Image.new("RGB", (1024, 500), BLUE)
    d = ImageDraw.Draw(fg)
    for y in range(500):
        t = y / 499
        d.line([(0, y), (1024, y)], fill=tuple(int(BLUE[i] * (1 - t) + DARK[i] * t) for i in range(3)))
    glyph = calendar(300, background=False)
    fg.paste(glyph, (60, 100), glyph)
    d.text((960, 200), "לוח עברי", font=font(110, 800), fill=WHITE, anchor="rm", direction="rtl")
    d.text((960, 320), "יומן לפי התאריך העברי", font=font(48, 400), fill=LIGHT,
           anchor="rm", direction="rtl")
    write(f"{STORE}/featureGraphic.png", fg)


if __name__ == "__main__":
    launcher_icons()
    store_images()
    print("brand assets written")
