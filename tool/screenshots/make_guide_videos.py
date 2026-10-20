#!/usr/bin/env python3
"""Makes the user guide's short videos (site/guide.html).

Input: build/store_raw/v_*.png and build/store_raw/video_marks_*.json from
tool/screenshots/capture_guide_videos_*test.dart. Output:
site/assets/guide/video/<name>.mp4 and a poster <name>.jpg for each.
The drawing is in guide_video_fx.py, and what each video says is in
guide_videos_start.py, _events.py and _learning.py (by guide chapter).

Run from the repo root: python3 tool/screenshots/make_guide_videos.py [name]
"""

import glob
import json
import os
import sys

import guide_videos_events as events
import guide_videos_learning as learning
import guide_videos_start as start
from guide_video_fx import ROOT, render

RAW = os.path.join(ROOT, "build/store_raw")
OUT = os.path.join(ROOT, "site/assets/guide/video")

# Scene: the step image, seconds on screen, effects on its marks
# (("frame" | "marker", mark)), a bubble (text, mark or None, "auto" |
# "top" | "bottom"), whether a finger presses its "tap" mark at the end
# ("tap"), swipes across its "swipe" mark ("swipe": "left" | "right") or
# is held down on a mark the whole scene ("press": mark).
VIDEOS = {**start.VIDEOS, **events.VIDEOS, **learning.VIDEOS}


def main():
    marks = {}
    for path in glob.glob(os.path.join(RAW, "video_marks_*.json")):
        with open(path, encoding="utf-8") as f:
            marks.update(json.load(f))
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or VIDEOS:
        render(VIDEOS[name], RAW, marks, os.path.join(OUT, name + ".mp4"),
               poster=os.path.join(OUT, name + ".jpg"))
        print("wrote", name)


if __name__ == "__main__":
    main()
