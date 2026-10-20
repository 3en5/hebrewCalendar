#!/usr/bin/env python3
"""Makes the user guide's short videos (site/guide.html).

Input: build/store_raw/v_*.png and build/store_raw/video_marks.json from
tool/screenshots/capture_guide_videos_test.dart. Output:
site/assets/guide/video/<name>.mp4 and a poster <name>.jpg for each.
The drawing is in guide_video_fx.py; here is what each video says.

Run from the repo root: python3 tool/screenshots/make_guide_videos.py [name]
"""

import json
import os
import sys

from guide_video_fx import ROOT, render

RAW = os.path.join(ROOT, "build/store_raw")
OUT = os.path.join(ROOT, "site/assets/guide/video")

# Scene: the step image, seconds on screen, effects on its marks
# (("frame" | "marker", mark)), a bubble (text, mark or None, "auto" |
# "top" | "bottom"), and whether a finger presses its "tap" mark at the end.
VIDEOS = {
    "recurrence": {
        "title": "אירוע חוזר לפי התאריך העברי",
        "scenes": [
            {"img": "v_rec_1", "dur": 2.6, "tap": True,
             "bubble": ("לוחצים על הכפתור הכתום כדי להוסיף אירוע", "tap", "auto")},
            {"img": "v_rec_2", "dur": 2.4, "tap": True,
             "bubble": ("בוחרים \"אירוע עברי חדש\"", "tap", "auto")},
            {"img": "v_rec_3", "dur": 3.0, "tap": True,
             "fx": [("marker", "title")],
             "bubble": ("כותבים שם, ואז נוגעים ב\"ללא חזרה\"", "tap", "auto")},
            {"img": "v_rec_4", "dur": 2.4, "tap": True,
             "bubble": ("\"כל שנה (עברי)\": באותו תאריך עברי, כל שנה",
                        "tap", "auto")},
            {"img": "v_rec_5", "dur": 3.6, "tap": True,
             "fx": [("frame", "adar")],
             "bubble": ("נולד באדר? בוחרים מה יקרה בשנה מעוברת", "adar",
                        "auto")},
            {"img": "v_rec_6", "dur": 2.6, "tap": True,
             "fx": [("marker", "repeat")],
             "bubble": ("שומרים בסימן ה-V שלמעלה", "tap", "auto")},
            {"img": "v_rec_7", "dur": 3.0,
             "fx": [("frame", "cell"), ("marker", "event")],
             "bubble": ("האירוע בלוח: י׳ אדר ב׳ תשפ״ז", "cell", "auto")},
            {"img": "v_rec_8", "dur": 3.4,
             "fx": [("frame", "cell"), ("marker", "event")],
             "bubble": ("ובשנה הבאה הוא שוב ב-י׳ אדר, גם אם התאריך הלועזי זז",
                        "cell", "auto")},
        ],
    },
}


def main():
    with open(os.path.join(RAW, "video_marks.json"), encoding="utf-8") as f:
        marks = json.load(f)
    os.makedirs(OUT, exist_ok=True)
    for name in sys.argv[1:] or VIDEOS:
        render(VIDEOS[name], RAW, marks, os.path.join(OUT, name + ".mp4"),
               poster=os.path.join(OUT, name + ".jpg"))
        print("wrote", name)


if __name__ == "__main__":
    main()
