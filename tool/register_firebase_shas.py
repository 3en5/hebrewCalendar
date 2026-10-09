#!/usr/bin/env python3
"""Registers the app's signing-certificate fingerprints in Firebase.

Google Sign-In only works for builds whose signing certificate SHA is
registered on the Firebase Android app. Builds installed from Google Play are
re-signed with the Play App Signing key, so its fingerprint must be registered
too. This script (run by .github/workflows/firebase-shas.yml):

1. finds the Firebase Android app for PACKAGE_NAME in FIREBASE_PROJECT,
2. reads the Play App Signing certificate by downloading the universal APK
   Play generated for the latest bundle on the given track,
3. adds every fingerprint from that APK and from EXTRA_SHAS (e.g. the upload
   key) that Firebase does not have yet.

Credentials: the GOOGLE_PLAY_KEY service account JSON, which needs the
Firebase Admin role on FIREBASE_PROJECT and Play Console access to the app.
"""

import glob
import json
import os
import subprocess
import sys
import tempfile

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

FIREBASE = "https://firebase.googleapis.com/v1beta1"
PLAY = "https://androidpublisher.googleapis.com/androidpublisher/v3/applications"
SCOPES = [
    "https://www.googleapis.com/auth/firebase",
    "https://www.googleapis.com/auth/cloud-platform",
    "https://www.googleapis.com/auth/androidpublisher",
]


def session_from_env():
    info = json.loads(os.environ["GOOGLE_PLAY_KEY"])
    creds = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    creds.refresh(Request())
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    return s


def call(s, method, url, **kw):
    r = s.request(method, url, timeout=120, **kw)
    if r.status_code >= 400:
        sys.exit(f"{method} {url} -> {r.status_code}: {r.text[:800]}")
    return r


def fb_headers(project):
    # Bill/quota Firebase Management API calls to the Firebase project (where
    # the API is enabled) instead of the service account's own project.
    return {"x-goog-user-project": project}


def firebase_app(s, project, package):
    apps = call(s, "GET", f"{FIREBASE}/projects/{project}/androidApps",
                headers=fb_headers(project)).json()
    for app in apps.get("apps", []):
        if app.get("packageName") == package:
            return app["name"]
    sys.exit(f"No Firebase Android app with package {package} in {project}")


def latest_version_code(s, package, track):
    edit = call(s, "POST", f"{PLAY}/{package}/edits").json()["id"]
    try:
        t = call(s, "GET", f"{PLAY}/{package}/edits/{edit}/tracks/{track}").json()
    finally:
        s.delete(f"{PLAY}/{package}/edits/{edit}", timeout=60)
    codes = [int(c) for r in t.get("releases", []) for c in r.get("versionCodes", [])]
    if not codes:
        sys.exit(f"No releases with version codes on track '{track}'")
    return max(codes)


def play_signing_shas(s, package, version_code):
    gen = call(s, "GET", f"{PLAY}/{package}/generatedApks/{version_code}").json()
    download_id = None
    for g in gen.get("generatedApks", []):
        universal = g.get("generatedUniversalApk")
        if universal:
            download_id = universal["downloadId"]
            break
    if not download_id:
        sys.exit(f"Play generated no universal APK for versionCode {version_code}")
    apk = call(
        s,
        "GET",
        f"{PLAY}/{package}/generatedApks/{version_code}/downloads/{download_id}:download",
        params={"alt": "media"},
    ).content
    if not apk.startswith(b"PK"):
        sys.exit(f"Downloaded file is not an APK (starts with {apk[:60]!r})")
    with tempfile.NamedTemporaryFile(suffix=".apk") as f:
        f.write(apk)
        f.flush()
        # The APK may be signed with v2+ schemes only (minSdk >= 24), which
        # `keytool -printcert -jarfile` cannot read; apksigner reads all, so
        # it goes first and keytool is the fallback.
        r = subprocess.run([apksigner(), "verify", "--print-certs", f.name],
                           capture_output=True, text=True)
        shas = parse_apksigner(r.stdout)
        if shas:
            return shas
        print(f"apksigner exit {r.returncode}: {r.stdout[-800:]} {r.stderr[-800:]}")
        r = subprocess.run(["keytool", "-printcert", "-jarfile", f.name],
                           capture_output=True, text=True)
        shas = parse_keytool(r.stdout)
        if shas:
            return shas
        sys.exit(f"keytool exit {r.returncode}: {r.stdout[-800:]} {r.stderr[-800:]}")


def apksigner():
    root = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    tools = sorted(glob.glob(f"{root}/build-tools/*/apksigner")) if root else []
    if not tools:
        sys.exit("apksigner not found under $ANDROID_HOME/build-tools")
    return tools[-1]


def parse_apksigner(text):
    shas = []
    for line in text.splitlines():
        for marker, kind in (("certificate SHA-1 digest:", "SHA_1"),
                             ("certificate SHA-256 digest:", "SHA_256")):
            if marker in line:
                shas.append((normalize(line.split(marker, 1)[1]), kind))
    return shas


def parse_keytool(text):
    shas = []
    for line in text.splitlines():
        line = line.strip()
        for prefix, kind in (("SHA1:", "SHA_1"), ("SHA256:", "SHA_256")):
            if line.startswith(prefix):
                shas.append((normalize(line[len(prefix):]), kind))
    return shas


def normalize(sha):
    return sha.replace(":", "").strip().lower()


def main():
    project = os.environ["FIREBASE_PROJECT"]
    package = os.environ["PACKAGE_NAME"]
    track = os.environ.get("TRACK", "internal")
    s = session_from_env()

    app = firebase_app(s, project, package)
    existing = {
        normalize(c["shaHash"])
        for c in call(s, "GET", f"{FIREBASE}/{app}/sha",
                      headers=fb_headers(project)).json().get("certificates", [])
    }

    code = latest_version_code(s, package, track)
    wanted = play_signing_shas(s, package, code)
    print(f"Play App Signing certificate (versionCode {code}): {[h for h, _ in wanted]}")
    wanted += parse_keytool(os.environ.get("EXTRA_SHAS", ""))

    added = 0
    for sha, kind in wanted:
        if sha in existing:
            print(f"already registered: {kind} {sha}")
            continue
        call(s, "POST", f"{FIREBASE}/{app}/sha", headers=fb_headers(project),
             json={"shaHash": sha, "certType": kind})
        existing.add(sha)
        added += 1
        print(f"added: {kind} {sha}")
    print(f"Done: {added} fingerprint(s) added to {app}")


if __name__ == "__main__":
    main()
