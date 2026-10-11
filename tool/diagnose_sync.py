#!/usr/bin/env python3
"""Read-only Google-sync diagnostics from Firestore (no event content).

For every user document prints: whether Google sync is enabled, whether a
sync token exists, the last successful sync time, the last sync error, and
how many events the user owns. Used to debug device reports like "sync
stuck on 'מסנכרן...'" without asking the owner for logs.

Env: GOOGLE_PLAY_KEY (service-account JSON with Firebase Admin on the
project), FIREBASE_PROJECT.
"""
import json
import os
import sys

import requests
from google.auth.transport.requests import Request
from google.oauth2 import service_account

SCOPES = ["https://www.googleapis.com/auth/datastore"]


def main():
    project = os.environ["FIREBASE_PROJECT"]
    info = json.loads(os.environ["GOOGLE_PLAY_KEY"])
    creds = service_account.Credentials.from_service_account_info(info, scopes=SCOPES)
    creds.refresh(Request())
    s = requests.Session()
    s.headers["Authorization"] = f"Bearer {creds.token}"
    s.headers["x-goog-user-project"] = project
    base = f"https://firestore.googleapis.com/v1/projects/{project}/databases/(default)/documents"

    r = s.get(f"{base}/users", params={"pageSize": 50}, timeout=60)
    if r.status_code >= 400:
        sys.exit(f"list users -> {r.status_code}: {r.text[:800]}")
    docs = r.json().get("documents", [])
    print(f"user documents: {len(docs)}")
    for doc in docs:
        uid = doc["name"].rsplit("/", 1)[-1]
        f = doc.get("fields", {})

        def val(key):
            v = f.get(key)
            if v is None:
                return None
            return next(iter(v.values()))

        count = s.post(
            f"{base}:runAggregationQuery",
            json={
                "structuredAggregationQuery": {
                    "structuredQuery": {
                        "from": [{"collectionId": "events"}],
                        "where": {
                            "fieldFilter": {
                                "field": {"fieldPath": "ownerUid"},
                                "op": "EQUAL",
                                "value": {"stringValue": uid},
                            }
                        },
                    },
                    "aggregations": [{"alias": "n", "count": {}}],
                }
            },
            timeout=60,
        )
        events = "?"
        if count.ok:
            events = count.json()[0]["result"]["aggregateFields"]["n"]["integerValue"]
        else:
            events = f"error {count.status_code}"
        err = val("googleLastSyncError")
        print(
            f"- user {uid[:6]}…: syncEnabled={val('googleSyncEnabled')} "
            f"hasSyncToken={val('googleSyncToken') is not None} "
            f"lastSyncedAt={val('googleLastSyncedAt')} events={events}"
        )
        print(f"  lastSyncError={err[:1500] if err else None}")
        print(f"  fields present: {sorted(f.keys())}; hasEmail={bool(val('email'))}")


if __name__ == "__main__":
    main()
