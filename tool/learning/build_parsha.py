#!/usr/bin/env python3
"""Builds the daily weekly-portion files served from Firebase Hosting (M26).

Input:
  * aliyot.json: the seven aliyot of every parsha (and of the combined
    parshiyot), from @hebcal/leyning, BSD-2-Clause, see aliyot.LICENSE.
  * From the Sefaria export (downloaded by this script, not committed):
    - the Torah, "Miqra according to the Masorah", CC-BY-SA;
    - Targum Onkelos, Torat Emet, Public Domain;
    - Rashi, the Rosenbaum-Silbermann Pentateuch (1929-1934), vocalized,
      Public Domain.

Output: site/learning/parsha/<parsha>-<aliyah>.json, one small file per
parsha and aliyah (day 1 = Sunday ... day 7 = Shabbat), so the app downloads
only the coming week. <parsha> is the app's parsha key (kosher_dart's Parsha
enum, lower case, e.g. "lech_lecha", "vayakhel_pekudei").

Nitzavim-Vayeilech has no combined division in the source: each of its days
is that day's aliyah of Nitzavim followed by that of Vayeilech.

Usage: python3 tool/learning/build_parsha.py [--cache DIR]
"""

import argparse
import json
import os
import re
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "site", "learning", "parsha")
EXPORT = "https://storage.googleapis.com/sefaria-export/json/Tanakh/"

BOOKS = [
    ("Genesis", "בראשית"),
    ("Exodus", "שמות"),
    ("Leviticus", "ויקרא"),
    ("Numbers", "במדבר"),
    ("Deuteronomy", "דברים"),
]

RASHI_VERSION = "Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann, 1929-1934"
# Numbers is published only in the corrected edition of the same book.
RASHI_VERSION_NUMBERS = (
    "Pentateuch with Rashi's commentary by M. Rosenbaum and A.M. Silbermann"
    " -- corrected vocalization"
)


def sources(book):
    rashi = RASHI_VERSION_NUMBERS if book == "Numbers" else RASHI_VERSION
    return {
        "mikra": f"Torah/{book}/Hebrew/Miqra according to the Masorah.json",
        "targum": f"Targum/Onkelos/Torah/Onkelos {book}/Hebrew/Onkelos {book}.json",
        "rashi": f"Rishonim on Tanakh/Rashi/Torah/Rashi on {book}/Hebrew/{rashi}.json",
    }


# hebcal's parsha name -> the app's key (kosher_dart Parsha enum).
KEYS = {
    "Bereshit": "bereshis", "Noach": "noach", "Lech-Lecha": "lech_lecha",
    "Vayera": "vayera", "Chayei Sara": "chayei_sara", "Toldot": "toldos",
    "Vayetzei": "vayetzei", "Vayishlach": "vayishlach", "Vayeshev": "vayeshev",
    "Miketz": "miketz", "Vayigash": "vayigash", "Vayechi": "vayechi",
    "Shemot": "shemos", "Vaera": "vaera", "Bo": "bo", "Beshalach": "beshalach",
    "Yitro": "yisro", "Mishpatim": "mishpatim", "Terumah": "terumah",
    "Tetzaveh": "tetzaveh", "Ki Tisa": "ki_sisa", "Vayakhel": "vayakhel",
    "Pekudei": "pekudei", "Vayikra": "vayikra", "Tzav": "tzav",
    "Shmini": "shmini", "Tazria": "tazria", "Metzora": "metzora",
    "Achrei Mot": "achrei_mos", "Kedoshim": "kedoshim", "Emor": "emor",
    "Behar": "behar", "Bechukotai": "bechukosai", "Bamidbar": "bamidbar",
    "Nasso": "nasso", "Beha'alotcha": "behaaloscha", "Sh'lach": "shlach",
    "Korach": "korach", "Chukat": "chukas", "Balak": "balak",
    "Pinchas": "pinchas", "Matot": "matos", "Masei": "masei",
    "Devarim": "devarim", "Vaetchanan": "vaeschanan", "Eikev": "eikev",
    "Re'eh": "reeh", "Shoftim": "shoftim", "Ki Teitzei": "ki_seitzei",
    "Ki Tavo": "ki_savo", "Nitzavim": "nitzavim", "Vayeilech": "vayeilech",
    "Ha'azinu": "haazinu", "Vezot Haberakhah": "vzos_haberacha",
    "Vayakhel-Pekudei": "vayakhel_pekudei", "Tazria-Metzora": "tazria_metzora",
    "Achrei Mot-Kedoshim": "achrei_mos_kedoshim",
    "Behar-Bechukotai": "behar_bechukosai", "Chukat-Balak": "chukas_balak",
    "Matot-Masei": "matos_masei",
}


def fetch(path, cache):
    local = os.path.join(cache, path.replace("/", "_"))
    if not os.path.exists(local):
        url = EXPORT + urllib.parse.quote(path)
        print("downloading", path, file=sys.stderr)
        with urllib.request.urlopen(url, timeout=120) as r, open(local, "wb") as f:
            f.write(r.read())
    with open(local, encoding="utf-8") as f:
        return json.load(f)


def clean_mikra(text):
    """MAM's HTML to plain text, and the section break after the verse."""
    brk = "פ" if "mam-spi-pe" in text else ("ס" if "mam-spi-samekh" in text else None)
    text = re.sub(r'<span class="mam-spi-(pe|samekh)">\{.\}</span>', "", text)
    text = re.sub(r'<sup class="footnote-marker">.*?</sup>\s*<i class="footnote">.*?</i>', "", text)
    text = re.sub(r"<[^>]+>", "", text)
    text = text.replace("&nbsp;", " ").replace("&thinsp;", " ")
    return re.sub(r"\s+", " ", text).strip(), brk


def clean_plain(text):
    text = re.sub(r"<[^>]+>", "", text).replace("&nbsp;", " ")
    return re.sub(r"\s+", " ", text).strip()


def clean_rashi(text):
    """One Rashi comment as [heading, body]; the heading is the bold quote."""
    text = re.sub(r'<sup class="footnote-marker">.*?</sup>\s*<i class="footnote">.*?</i>', "", text)
    m = re.match(r"\s*<b>(.*?)</b>(.*)", text, re.S)
    head, body = (m.group(1), m.group(2)) if m else ("", text)
    return [clean_plain(head), clean_plain(body)]


def verse_ref(ref):
    c, v = ref.split(":")
    return int(c), int(v)


def verses_between(start, end, chapters):
    """All (chapter, verse) from start to end inclusive, across chapters."""
    c, v = start
    out = []
    while (c, v) <= end:
        out.append((c, v))
        v += 1
        if v > chapters[c - 1]:
            c, v = c + 1, 1
    return out


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--cache", default=os.path.join(ROOT, "build", "sefaria"))
    args = parser.parse_args()
    os.makedirs(args.cache, exist_ok=True)

    texts = {}
    for book, hebrew in BOOKS:
        src = {k: fetch(p, args.cache)["text"] for k, p in sources(book).items()}
        texts[BOOKS.index((book, hebrew)) + 1] = (hebrew, src)

    with open(os.path.join(HERE, "aliyot.json"), encoding="utf-8") as f:
        aliyot = json.load(f)

    def portion(name, n):
        entry = aliyot[name]
        hebrew, src = texts[entry["book"]]
        chapters = [len(ch) for ch in src["mikra"]]
        # A few entries carry a third item, a note on other customs.
        b, e = entry["aliyot"][str(n)][:2]
        verses = []
        for c, v in verses_between(verse_ref(b), verse_ref(e), chapters):
            mikra, brk = clean_mikra(src["mikra"][c - 1][v - 1])
            targum = clean_plain(src["targum"][c - 1][v - 1])
            rashi_ch = src["rashi"][c - 1] if c <= len(src["rashi"]) else []
            rashi = rashi_ch[v - 1] if v <= len(rashi_ch) else []
            if not mikra or not targum:
                sys.exit(f"missing text: {name} {c}:{v}")
            item = {"c": c, "v": v, "m": mikra, "t": targum}
            comments = [clean_rashi(r) for r in rashi if clean_plain(r)]
            if comments:
                item["r"] = comments
            if brk:
                item["b"] = brk
            verses.append(item)
        return {"book": hebrew, "from": b, "to": e, "verses": verses}

    os.makedirs(OUT, exist_ok=True)
    for old in os.listdir(OUT):
        os.remove(os.path.join(OUT, old))
    written = 0
    covered = set()
    for name, key in KEYS.items():
        for n in range(1, 8):
            data = {"parts": [portion(name, n)]}
            for part in data["parts"]:
                covered.update((aliyot[name]["book"], x["c"], x["v"]) for x in part["verses"])
            with open(os.path.join(OUT, f"{key}-{n}.json"), "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
            written += 1
    for n in range(1, 8):
        data = {"parts": [portion("Nitzavim", n), portion("Vayeilech", n)]}
        with open(os.path.join(OUT, f"nitzavim_vayeilech-{n}.json"), "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, separators=(",", ":"))
        written += 1

    # Every verse of the Torah is in some regular parsha's week.
    total = sum(len(src["mikra"][c]) for _, src in texts.values() for c in range(len(src["mikra"])))
    if len(covered) != total:
        sys.exit(f"coverage: {len(covered)} of {total} verses")
    size = sum(os.path.getsize(os.path.join(OUT, f)) for f in os.listdir(OUT))
    print(f"{written} files, {total} verses covered, {size // 1024} KB")


if __name__ == "__main__":
    main()
