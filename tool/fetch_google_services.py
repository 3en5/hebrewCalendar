#!/usr/bin/env python3
"""Downloads the current google-services.json from Firebase.

Used by .github/workflows/release.yml so a release always carries the config
that matches the fingerprints registered on the Firebase Android app (see
tool/register_firebase_shas.py), instead of a copy pasted into a secret.

Env: GOOGLE_PLAY_KEY (service account JSON with Firebase Admin and Service
Usage Consumer on FIREBASE_PROJECT), FIREBASE_PROJECT, PACKAGE_NAME.
Usage: fetch_google_services.py <output path>
"""

import base64
import os
import sys

from register_firebase_shas import FIREBASE, call, fb_headers, firebase_app, session_from_env


def main():
    out = sys.argv[1]
    project = os.environ["FIREBASE_PROJECT"]
    s = session_from_env()
    app = firebase_app(s, project, os.environ["PACKAGE_NAME"])
    cfg = call(s, "GET", f"{FIREBASE}/{app}/config", headers=fb_headers(project)).json()
    with open(out, "wb") as f:
        f.write(base64.b64decode(cfg["configFileContents"]))
    print(f"Wrote {cfg.get('configFilename', 'google-services.json')} for {app} to {out}")


if __name__ == "__main__":
    main()
