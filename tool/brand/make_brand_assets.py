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
- site/assets/icon.png                                   the same icon for the site
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
EXTENT = 922                   # the 2026-10-11 drawing's width on the grid

ACCENT = (232, 131, 58)        # the app's orange add button, #E8833A
# Owner decision 2026-10-15 (sketch 47, option "11b"): the calendar page,
# the app's own symbol, is large and filled with a warm orange-to-red
# gradient over the blue house (80%) and gear (moved left).
STYLE = {"kind": "filled", "accent": ACCENT, "gradient": ((245, 150, 50), (222, 60, 45)),
         "scale": 1.85, "origin": (560, 590), "halo": True, "house": 0.8, "gear_dx": -150}


def glyph(size, style=None):
    """The line-art icon on a transparent size x size canvas (1024 design grid).

    [style] picks how the calendar page, the app's own symbol, stands out
    from the blue house and gear: "line" (blue outline, the 2026-10-11
    design) or a larger accent page: "outline", "filled" or "header".
    """
    style = style or STYLE
    accent = style.get("accent", LINE)
    kind = style.get("kind", "line")
    f = style.get("scale", 1.0)
    s = 1024 * SUPERSAMPLE
    k = SUPERSAMPLE
    m = 400  # margin, so a larger page is not cut at the grid's edge
    im = Image.new("RGBA", (s + 2 * m * k, s + 2 * m * k), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    w = 34 * k

    def p(*pts):
        return [((x + m) * k, (y + m) * k) for x, y in pts]

    def box(x0, y0, x1, y1):
        return [(x0 + m) * k, (y0 + m) * k, (x1 + m) * k, (y1 + m) * k]

    # House: roof, wall and floor, window with its cross; [house] shrinks
    # it about its bottom-left corner.
    hs = style.get("house", 1.0)

    def h(*pts):
        return p(*[(110 + (x - 110) * hs, 740 + (y - 740) * hs) for x, y in pts])

    d.line(h((440, 740), (110, 740), (110, 370), (60, 370), (355, 75), (560, 280)),
           fill=LINE, width=w, joint="curve")
    d.rounded_rectangle(sum(map(list, h((215, 390), (415, 590))), []),
                        radius=14 * k, outline=LINE, width=w)
    d.line(h((315, 390), (315, 590)), fill=LINE, width=w)
    d.line(h((215, 490), (415, 490)), fill=LINE, width=w)

    # Calendar page with binding rings and "א", grown by f about [origin].
    ox, oy = style.get("origin", (760, 395))

    def c(x, y):
        return ((ox + (x - ox) * f + m) * k, (oy + (y - oy) * f + m) * k)

    cw = int(w * style.get("stroke", 1.0))
    left, top = c(560, 200)
    right, bottom = c(960, 590)
    head = c(0, 300)[1]
    r = 40 * f * k
    body = accent if kind == "filled" else WHITE
    edge = LINE if kind in ("line", "badge") else accent
    if style.get("halo"):
        # A white margin cuts the house's lines where the page covers them.
        g = cw * 1.4
        d.rounded_rectangle([left - g, top - g, right + g, bottom + g],
                            radius=r + g, fill=WHITE)
    d.rounded_rectangle([left, top, right, bottom], radius=r, fill=body,
                        outline=edge, width=cw)
    if kind == "filled" and style.get("gradient"):
        # Top-to-bottom gradient over the page's whole shape.
        top_c, bottom_c = style["gradient"]
        shape = Image.new("L", im.size, 0)
        ImageDraw.Draw(shape).rounded_rectangle(
            [left - cw / 2, top - cw / 2, right + cw / 2, bottom + cw / 2],
            radius=r + cw / 2, fill=255)
        fill = Image.new("RGBA", im.size, top_c)
        fd = ImageDraw.Draw(fill)
        for y in range(int(top - cw), int(bottom + cw) + 1):
            t = min(1, max(0, (y - top) / max(1, bottom - top)))
            fd.line([(left - cw, y), (right + cw, y)],
                    fill=tuple(int(top_c[i] * (1 - t) + bottom_c[i] * t) for i in range(3)))
        im.paste(fill, (0, 0), shape)
    if kind == "header":
        d.rounded_rectangle([left, top, right, head + cw / 2], radius=r, fill=accent)
        d.rectangle([left, head - r, right, head + cw / 2], fill=accent)
    else:
        d.line([(left, head), (right, head)],
               fill=WHITE if kind == "filled" else edge, width=cw)
    for x in (665, 855):
        x0, y0 = c(x, 150)
        y1 = c(x, 240)[1]
        if kind != "line":
            d.line([(x0, y0), (x0, y1)], fill=WHITE, width=cw * 2)
        d.line([(x0, y0), (x0, y1)], fill=edge, width=cw)
    if kind != "badge":
        d.text(c(760, 550), "א", font=ImageFont.truetype(FONT_BOLD, int(240 * f * k)),
               fill=WHITE if kind == "filled" else edge, anchor="ms", direction="rtl")
    if style.get("moon"):
        # A crescent: the Hebrew months follow the moon.
        mx, my = c(*style["moon"])
        mr = 38 * f * k
        moon = Image.new("L", im.size, 0)
        md = ImageDraw.Draw(moon)
        md.ellipse([mx - mr, my - mr, mx + mr, my + mr], fill=255)
        md.ellipse([mx - mr * 0.45, my - mr * 1.1, mx + mr * 1.55, my + mr * 0.9], fill=0)
        im.paste(Image.new("RGBA", im.size, WHITE), (0, 0), moon)

    # Gear: eight teeth around a hole, overlapping the house's corner. A
    # white halo keeps it apart from the larger page behind it.
    cx, cy, outer, inner, teeth = 640 + style.get("gear_dx", 0), 735, 158, 122, 8
    pts = []
    for i in range(teeth * 4):
        a = 2 * math.pi * (i - 0.5) / (teeth * 4)
        rr = outer if i % 4 in (0, 1) else inner
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    if kind != "line":
        d.polygon(p(*pts), fill=WHITE)
        d.line(p(*pts, pts[0]), fill=WHITE, width=int(w * 2.4), joint="curve")
    d.line(p(*pts, pts[0]), fill=LINE, width=w, joint="curve")
    d.ellipse(box(cx - 62, cy - 62, cx + 62, cy + 62),
              outline=LINE, width=w)

    if kind == "badge":
        # The "א" moves to an accent badge on the page's corner.
        bx, by = c(*style.get("badge", (930, 590)))
        br = style.get("badge_r", 170) * k
        g = cw * 1.2
        d.ellipse([bx - br - g, by - br - g, bx + br + g, by + br + g], fill=WHITE)
        d.ellipse([bx - br, by - br, bx + br, by + br], fill=accent)
        d.text((bx, by + br * 0.42), "א", font=ImageFont.truetype(FONT_BOLD, int(br * 1.25)),
               fill=WHITE, anchor="ms", direction="rtl")

    # A larger page widens the drawing: shrink it back to the original
    # extent, centred on the grid.
    if kind == "line":
        im = im.crop((m * k, m * k, m * k + s, m * k + s))
    else:
        crop = im.crop(im.getbbox())
        t = EXTENT * k / max(crop.width, crop.height)
        crop = crop.resize((int(crop.width * t), int(crop.height * t)), Image.LANCZOS)
        im = Image.new("RGBA", (s, s), (0, 0, 0, 0))
        im.paste(crop, ((s - crop.width) // 2, (s - crop.height) // 2), crop)
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
    icon = tile(512, 0.82).convert("RGB")
    write(f"{STORE}/icon.png", icon)
    write(f"{ROOT}/site/assets/icon.png", icon)
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
