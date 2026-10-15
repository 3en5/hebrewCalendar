#!/usr/bin/env python3
"""Builds the daily Kitzur Shulchan Aruch files served from Firebase Hosting.

Input:
  * ksa_schedule.json: the yearly Kitzur Shulchan Aruch Yomi schedule
    (from @hebcal/learning, BSD-2-Clause, see ksa_schedule.LICENSE). Keyed by
    Hebrew month, one "siman:seif-siman:seif" range per day ("E" = end of
    the siman). The cycle starts on 24 Tishrei and repeats every year.
  * The Hebrew text, "Torat Emet 357" edition, Public Domain, from the
    Sefaria export (downloaded by this script, not committed).

Output: site/halacha/ksa/<month>-<day>.json, one small file per day, so the
app downloads only the coming week.

The schedule has a few typing slips (e.g. "5:9-6:16" where siman 5 ends at
17 and the next day starts at "6:17"). Each day is checked against the real
seif counts and kept contiguous with the day before; the script prints every
correction and fails if the regular cycle does not cover the whole book.

Usage: python3 tool/halacha/build_ksa.py [--text path/to/torat_emet.json]
"""

import argparse
import json
import os
import re
import sys
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "site", "halacha", "ksa")
TEXT_URL = (
    "https://storage.googleapis.com/sefaria-export/json/Halakhah/"
    "Kitzur%20Shulchan%20Arukh/Hebrew/Torat%20Emet%20357.json"
)

# Schedule month key -> the app's HebrewMonth name. "Adar" is the plain
# Adar of a common year and Adar I of a leap year; Adar II of a leap year
# uses option B (review of the laws of blessings and prayer; option A,
# laws of the Land, is not in the Kitzur text).
MONTHS = [
    ("Tishrei", "tishrei"),
    ("Cheshvan", "cheshvan"),
    ("Kislev", "kislev"),
    ("Tevet", "tevet"),
    ("Sh'vat", "shvat"),
    ("Adar", "adar"),
    ("Nisan", "nisan"),
    ("Iyyar", "iyar"),
    ("Sivan", "sivan"),
    ("Tamuz", "tammuz"),
    ("Av", "av"),
    ("Elul", "elul"),
]
LEAP_KEY = ("Leap Option B", "adarII")

# Slips the automatic checks can't see. 21 Nisan repeats siman 104 (read
# on 20 Nisan) and never reaches siman 106 (commerce on Chol HaMoed), the
# only part of the book the cycle would otherwise skip.
OVERRIDES = {"Nisan 21": "105:1-106:E"}


def clean(html):
    text = re.sub(r"<br\s*/?>", "\n", html)
    text = re.sub(r"<[^>]+>", "", text)
    return re.sub(r"[ \t]+", " ", text).strip()


class Book:
    def __init__(self, simanim):
        self.counts = [len(s) for s in simanim]
        self.text = simanim
        self.order = [
            (si + 1, se + 1)
            for si, s in enumerate(simanim)
            for se in range(len(s))
        ]
        self.index = {p: i for i, p in enumerate(self.order)}

    def valid(self, p):
        return p in self.index

    def last(self, siman):
        return (siman, self.counts[siman - 1])

    def after(self, p):
        i = self.index[p] + 1
        return self.order[i] if i < len(self.order) else None


def resolve(book, raw, prev_end, label, notes):
    # Read the four parts whatever the separators ("17-8:18-2" is
    # 17:8-18:2); three parts mean an end within the same siman.
    parts = re.findall(r"\d+|E", raw)
    if len(parts) == 3:
        parts = [parts[0], parts[1], parts[0], parts[2]]
    if len(parts) != 4:
        raise SystemExit(f"{label}: cannot read {raw}")
    b_raw, e_raw = (
        (int(parts[i]), parts[i + 1] if parts[i + 1] == "E" else int(parts[i + 1]))
        for i in (0, 2)
    )
    expected = book.after(prev_end) if prev_end else None

    def concrete(p):
        if p[1] == "E":
            return book.last(p[0]) if 1 <= p[0] <= len(book.counts) else None
        return p if book.valid(p) else None

    begin = concrete(b_raw)
    if expected and begin != expected:
        near = begin and abs(book.index[begin] - book.index[expected]) <= 3
        if begin is None or near:
            notes.append(f"{label}: begin {raw} -> {expected}")
            begin = expected
    if begin is None:
        raise SystemExit(f"{label}: cannot place begin of {raw}")

    end = concrete(e_raw)
    starts = [begin] + ([expected] if expected and expected != begin else [])

    def fits(start, c):
        if not (c and book.valid(c)):
            return False
        return 0 <= book.index[c] - book.index[start] <= 45

    def found(start, c):
        if start != begin:
            notes.append(f"{label}: begin {raw} -> {start}")
        if c != end:
            notes.append(f"{label}: end {raw} -> {c}")
        return start, c

    # First the end as written, from either start.
    for start in starts:
        if fits(start, end):
            return found(start, end)

    # Then a mistyped siman number: one of the next simanim whose number
    # matches the written digits ("4" for 134, "1234" for 124), the longest
    # such reading first (a day is rarely a single seif).
    def digits_match(a, b):
        it = iter(b)
        return all(ch in it for ch in a)

    if e_raw[1] != "E":
        for start in starts:
            options = [
                (siman, e_raw[1])
                for siman in range(start[0], start[0] + 3)
                if fits(start, (siman, e_raw[1]))
            ]
            written = str(e_raw[0])
            matching = [
                c
                for c in options
                if digits_match(str(c[0]), written)
                or digits_match(written, str(c[0]))
            ]
            for pool in (matching, options):
                if pool:
                    best = max(pool, key=lambda c: book.index[c])
                    return found(start, best)
    raise SystemExit(f"{label}: cannot place end of {raw}")


def numeral(n):
    ones = ["", "א", "ב", "ג", "ד", "ה", "ו", "ז", "ח", "ט"]
    tens = ["", "י", "כ", "ל", "מ", "נ", "ס", "ע", "פ", "צ"]
    hundreds = ["", "ק", "ר", "ש", "ת"]
    out = hundreds[n // 100]
    rest = n % 100
    if rest == 15:
        out += "טו"
    elif rest == 16:
        out += "טז"
    else:
        out += tens[rest // 10] + ones[rest % 10]
    if len(out) == 1:
        return out + "׳"
    return out[:-1] + "״" + out[-1]


def title(begin, end):
    if begin[0] == end[0]:
        return (
            f"סימן {numeral(begin[0])}, סעיפים "
            f"{numeral(begin[1])}–{numeral(end[1])}"
            if begin != end
            else f"סימן {numeral(begin[0])}, סעיף {numeral(begin[1])}"
        )
    return (
        f"סימן {numeral(begin[0])} סעיף {numeral(begin[1])} – "
        f"סימן {numeral(end[0])} סעיף {numeral(end[1])}"
    )


def day_file(book, begin, end):
    sections = []
    i = book.index[begin]
    while True:
        siman, seif = book.order[i]
        sections.append(
            {
                "siman": siman,
                "seif": seif,
                "text": clean(book.text[siman - 1][seif - 1]),
            }
        )
        if (siman, seif) == end:
            break
        i += 1
    return {"title": title(begin, end), "sections": sections}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--text", help="local copy of the Torat Emet 357 JSON")
    args = ap.parse_args()
    if args.text:
        with open(args.text, encoding="utf-8") as f:
            source = json.load(f)
    else:
        with urllib.request.urlopen(TEXT_URL, timeout=120) as r:
            source = json.load(r)
    if source.get("license") != "Public Domain":
        raise SystemExit(f"unexpected license: {source.get('license')}")
    book = Book(source["text"])
    with open(os.path.join(HERE, "ksa_schedule.json"), encoding="utf-8") as f:
        schedule = json.load(f)

    # The regular cycle in study order: 24 Tishrei to 23 Tishrei.
    days = []
    for key, name in MONTHS:
        for d, raw in enumerate(schedule[key], start=1):
            days.append((key, name, d, raw))
    start = next(i for i, x in enumerate(days) if x[0] == "Tishrei" and x[2] == 24)
    cycle = days[start:] + days[:start]

    notes = []
    files = {}
    covered = set()
    prev = None
    for key, name, d, raw in cycle:
        if ":" not in raw:
            # "Klalim" (15 Elul): the principles of the Shulchan Aruch, not
            # part of the Kitzur text. No file; the app shows no halacha.
            notes.append(f"{key} {d}: '{raw}' has no Kitzur text, skipped")
            continue
        if f"{key} {d}" in OVERRIDES:
            notes.append(f"{key} {d}: {raw} -> {OVERRIDES[f'{key} {d}']}")
            raw = OVERRIDES[f"{key} {d}"]
        begin, end = resolve(book, raw, prev, f"{key} {d}", notes)
        files[f"{name}-{d}"] = day_file(book, begin, end)
        for i in range(book.index[begin], book.index[end] + 1):
            covered.add(book.order[i])
        prev = end
    prev = None
    for d, raw in enumerate(schedule[LEAP_KEY[0]], start=1):
        begin, end = resolve(book, raw, prev, f"{LEAP_KEY[0]} {d}", notes)
        files[f"{LEAP_KEY[1]}-{d}"] = day_file(book, begin, end)
        prev = end

    missing = [p for p in book.order if p not in covered]
    for n in notes:
        print("fixed:", n)
    print(f"{len(files)} days, {len(covered)}/{len(book.order)} seifim covered")
    if missing:
        print("not covered:", missing[:40], "..." if len(missing) > 40 else "")
    if len(missing) > 20:
        sys.exit("the regular cycle misses too much of the book")

    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        os.remove(os.path.join(OUT, old))
    for name, data in files.items():
        with open(os.path.join(OUT, f"{name}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))


if __name__ == "__main__":
    main()
