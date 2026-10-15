#!/usr/bin/env python3
"""Draws the user guide's highlights on its screenshots.

Input: build/store_raw/g_*.png and build/store_raw/guide_marks.json, both
from tool/screenshots/capture_guide_screens_test.dart (the marks are where
the real widgets were). Output: site/assets/guide/*.jpg for site/guide.html.

Each mark the guide talks about gets an orange frame; small ones (a button,
a cell) also get an arrow pointing at them. The rest of the screen is
dimmed a little so the marked parts stand out.

Run from the repo root: python3 tool/screenshots/annotate_guide.py
"""

import json
import math
import os

from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
RAW = os.path.join(ROOT, "build/store_raw")
OUT = os.path.join(ROOT, "site/assets/guide")

ORANGE = (232, 131, 58)   # the app's add button, AppTheme.addButtonColor
WHITE = (255, 255, 255)
DIM = 70                  # 0-255 darkness outside the frames
PAD = 14                  # frame distance from the widget, in image pixels
OUT_SIZE = (540, 1200)

# Shot -> (guide image name, [(mark, "arrow" or "frame")]).
SHOTS = {
    "g_month": ("month", [("cell", "arrow"), ("day", "frame")]),
    "g_view_menu": ("view-menu", [("menu", "arrow")]),
    "g_week": ("week", [("event", "arrow")]),
    "g_day": ("day", [("zmanim", "frame")]),
    "g_agenda": ("agenda", []),
    "g_day_pop": ("day-pop", [("pop", "arrow")]),
    "g_goto": ("goto", [("button", "arrow"), ("items", "frame")]),
    "g_search": ("search", [("field", "frame")]),
    "g_dark": ("dark", []),
    "g_add_menu": ("add-menu", [("items", "frame")]),
    "g_recurrence": ("recurrence", [("yearly", "frame"), ("adar", "arrow")]),
    "g_event_sheet": ("event-sheet", [("map", "arrow")]),
    "g_editor_delete": ("editor-delete", [("delete", "arrow")]),
    "g_significant": ("significant", [("kinds", "frame"), ("sunset", "frame"),
                                      ("preview", "frame")]),
    "g_settings": ("settings", [("sync", "frame")]),
    "g_text_size": ("text-size", [("size", "frame")]),
    "g_settings_more": ("settings-more", [("backup", "frame"), ("guide", "frame")]),
    "g_halacha": ("halacha", [("dedication", "frame"), ("learned", "frame")]),
}


def padded(box, size):
    l, t, r, b = box
    return [max(4, l - PAD), max(4, t - PAD), min(size[0] - 4, r + PAD),
            min(size[1] - 4, b + PAD)]


def arrow(draw, box, size):
    """An arrow from the roomier side towards the middle of [box]'s edge."""
    l, t, r, b = box
    cx, cy = (l + r) / 2, (t + b) / 2
    w, h = size
    room = {"left": l, "right": w - r, "top": t, "bottom": h - b}
    side = max(room, key=room.get)
    length = min(230, room[side] - 30)
    if length < 90:
        return
    # Slightly diagonal, which reads better than a straight line.
    if side in ("left", "right"):
        end = (l - 10, cy) if side == "left" else (r + 10, cy)
        sx = end[0] - length if side == "left" else end[0] + length
        sy = cy + (length * 0.45 if cy < h / 2 else -length * 0.45)
    else:
        end = (cx, t - 10) if side == "top" else (cx, b + 10)
        sy = end[1] - length if side == "top" else end[1] + length
        sx = cx + (length * 0.45 if cx < w / 2 else -length * 0.45)
    start = (min(max(sx, 20), w - 20), min(max(sy, 20), h - 20))
    ang = math.atan2(end[1] - start[1], end[0] - start[0])
    head = 46
    tip = end
    base = (tip[0] - head * math.cos(ang), tip[1] - head * math.sin(ang))
    left = (base[0] + head * 0.6 * math.sin(ang), base[1] - head * 0.6 * math.cos(ang))
    right = (base[0] - head * 0.6 * math.sin(ang), base[1] + head * 0.6 * math.cos(ang))
    for colour, grow in ((WHITE, 8), (ORANGE, 0)):
        draw.line([start, base], fill=colour, width=16 + grow * 2)
        draw.ellipse([start[0] - 8 - grow, start[1] - 8 - grow,
                      start[0] + 8 + grow, start[1] + 8 + grow], fill=colour)
        poly = [tip, left, right]
        if grow:
            # Grow the head outwards for the white outline.
            cxh = sum(p[0] for p in poly) / 3
            cyh = sum(p[1] for p in poly) / 3
            poly = [(cxh + (x - cxh) * 1.35, cyh + (y - cyh) * 1.35) for x, y in poly]
        draw.polygon(poly, fill=colour)


def annotate(src, marks, items):
    im = Image.open(src).convert("RGB")
    if not items:
        return im
    boxes = [(padded(marks[name], im.size), kind) for name, kind in items]
    # Dim everything but the frames.
    shade = Image.new("L", im.size, DIM)
    sd = ImageDraw.Draw(shade)
    for box, _ in boxes:
        sd.rounded_rectangle(box, radius=26, fill=0)
    im = Image.composite(Image.new("RGB", im.size, (0, 0, 0)), im, shade)
    d = ImageDraw.Draw(im)
    for box, _ in boxes:
        d.rounded_rectangle(box, radius=26, outline=WHITE, width=16)
        d.rounded_rectangle(box, radius=26, outline=ORANGE, width=9)
    for box, kind in boxes:
        if kind == "arrow":
            arrow(d, box, im.size)
    return im


def main():
    with open(os.path.join(RAW, "guide_marks.json"), encoding="utf-8") as f:
        all_marks = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    for shot, (name, items) in SHOTS.items():
        im = annotate(os.path.join(RAW, f"{shot}.png"), all_marks.get(shot, {}), items)
        im.resize(OUT_SIZE, Image.LANCZOS).save(
            os.path.join(OUT, f"{name}.jpg"), quality=82, optimize=True, progressive=True)
    print(f"{len(SHOTS)} guide images written")


if __name__ == "__main__":
    main()
