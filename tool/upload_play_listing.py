#!/usr/bin/env python3
"""Uploads the Google Play store listing from distribution/listings/.

Layout:
  distribution/listings/<lang>/{title,short_description,full_description}.txt
  distribution/listings/images/{icon,featureGraphic}.png         (all languages)
  distribution/listings/images/phoneScreenshots/*.png            (optional)

Every language directory (e.g. iw-IL, en-US) becomes a listing; images are
replaced (deleteall + upload) for each language. Runs in one Play "edit" that
is committed at the end, so a failure leaves the live listing unchanged.

Env: GOOGLE_PLAY_KEY (service account JSON with release access to the app),
PACKAGE_NAME. Used by .github/workflows/play-listing.yml.
"""

import glob
import os
import sys

from register_firebase_shas import PLAY, call, session_from_env

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LISTINGS = os.path.join(ROOT, "distribution/listings")
UPLOAD = "https://androidpublisher.googleapis.com/upload/androidpublisher/v3/applications"
LIMITS = {"title": 30, "short_description": 80, "full_description": 4000}


def read(lang, name):
    with open(os.path.join(LISTINGS, lang, f"{name}.txt"), encoding="utf-8") as f:
        text = f.read().strip()
    if len(text) > LIMITS[name]:
        sys.exit(f"{lang}/{name}.txt is {len(text)} chars (limit {LIMITS[name]})")
    return text


def images():
    out = {}
    for kind in ("icon", "featureGraphic"):
        path = os.path.join(LISTINGS, "images", f"{kind}.png")
        if os.path.exists(path):
            out[kind] = [path]
    shots = sorted(glob.glob(os.path.join(LISTINGS, "images/phoneScreenshots/*.png")))
    if shots:
        out["phoneScreenshots"] = shots
    return out


def main():
    package = os.environ["PACKAGE_NAME"]
    langs = sorted(d for d in os.listdir(LISTINGS)
                   if os.path.isfile(os.path.join(LISTINGS, d, "title.txt")))
    s = session_from_env()
    edit = call(s, "POST", f"{PLAY}/{package}/edits").json()["id"]
    base = f"{PLAY}/{package}/edits/{edit}"
    try:
        for lang in langs:
            call(s, "PUT", f"{base}/listings/{lang}", json={
                "language": lang,
                "title": read(lang, "title"),
                "shortDescription": read(lang, "short_description"),
                "fullDescription": read(lang, "full_description"),
            })
            print(f"listing text: {lang}")
            for kind, paths in images().items():
                call(s, "DELETE", f"{base}/listings/{lang}/{kind}")
                for path in paths:
                    with open(path, "rb") as f:
                        call(s, "POST", f"{UPLOAD}/{package}/edits/{edit}/listings/{lang}/{kind}",
                             params={"uploadType": "media"},
                             headers={"Content-Type": "image/png"}, data=f.read())
                print(f"  {kind}: {len(paths)} image(s)")
        call(s, "POST", f"{base}:commit")
        print(f"Committed listing for {', '.join(langs)}")
    except SystemExit:
        s.delete(base, timeout=60)
        raise


if __name__ == "__main__":
    main()
