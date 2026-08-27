#!/usr/bin/env python3
"""Upload an Android App Bundle to Google Play via the Developer API.

Usage:
  python tools/play_upload.py \
      --aab build/app/outputs/bundle/release/app-release.aab \
      --track internal \
      --service-account C:/Users/Admin/keys/play-service-account.json \
      --notes-bg "Първа версия за тестване" \
      --notes-en "First testing release"

Track values:
  internal | alpha | beta | production
  ...or the exact track name of a custom Closed-testing track from the Play Console.
  (Google's default Closed-testing track maps to "alpha".)

Prerequisite (one-time, USER side):
  Create a service account in Google Cloud, grant it access in Play Console
  (Users & permissions -> Invite -> app access: Release to testing tracks),
  download its JSON key, and point --service-account at it.
"""
import argparse
import sys
import time

from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE_DEFAULT = "com.ivoexp.habits"


def main() -> int:
    p = argparse.ArgumentParser(description="Upload an AAB to Google Play.")
    p.add_argument("--aab", default=None, help="Path to the .aab file (omit with --version-code)")
    p.add_argument("--version-code", type=int, default=None,
                   help="Assign an ALREADY-UPLOADED versionCode to --track (skips upload). "
                        "Use to promote an existing build to another track (e.g. production).")
    p.add_argument("--service-account", required=True, help="Path to service-account JSON")
    p.add_argument("--package", default=PACKAGE_DEFAULT)
    p.add_argument("--track", default="internal")
    p.add_argument("--status", default="completed",
                   choices=["completed", "draft", "halted", "inProgress"])
    p.add_argument("--notes-bg", default=None, help="Release notes (bg-BG)")
    p.add_argument("--notes-en", default=None, help="Release notes (en-US)")
    p.add_argument("--notes-bg-file", default=None,
                   help="UTF-8 file with bg-BG release notes (avoids CLI encoding issues)")
    p.add_argument("--notes-en-file", default=None,
                   help="UTF-8 file with en-US release notes")
    args = p.parse_args()

    if args.notes_bg_file:
        with open(args.notes_bg_file, encoding="utf-8") as fh:
            args.notes_bg = fh.read().strip()
    if args.notes_en_file:
        with open(args.notes_en_file, encoding="utf-8") as fh:
            args.notes_en = fh.read().strip()

    creds = service_account.Credentials.from_service_account_file(
        args.service_account, scopes=SCOPES)
    service = build("androidpublisher", "v3", credentials=creds, cache_discovery=False)
    edits = service.edits()

    if not args.aab and not args.version_code:
        p.error("provide --aab (to upload) or --version-code (to promote an existing build)")

    print(f"Opening edit for {args.package} ...")
    edit_id = edits.insert(body={}, packageName=args.package).execute()["id"]

    if args.version_code:
        version_code = args.version_code
        print(f"Promoting existing versionCode = {version_code} (no upload)")
    else:
        print(f"Uploading bundle {args.aab} ...")
        media = MediaFileUpload(args.aab, mimetype="application/octet-stream", resumable=True)
        bundle = edits.bundles().upload(
            editId=edit_id, packageName=args.package, media_body=media).execute()
        version_code = bundle["versionCode"]
        print(f"  uploaded versionCode = {version_code}")

    release = {"name": f"vc{version_code}", "versionCodes": [str(version_code)],
               "status": args.status}
    notes = []
    if args.notes_bg:
        notes.append({"language": "bg-BG", "text": args.notes_bg})
    if args.notes_en:
        notes.append({"language": "en-US", "text": args.notes_en})
    if notes:
        release["releaseNotes"] = notes

    print(f"Assigning to track '{args.track}' (status={args.status}) ...")
    edits.tracks().update(
        editId=edit_id, packageName=args.package, track=args.track,
        body={"track": args.track, "releases": [release]}).execute()

    print("Committing edit ...")
    for attempt in range(3):
        try:
            edits.commit(editId=edit_id, packageName=args.package).execute()
            break
        except Exception as e:  # noqa: BLE001 - surface + retry transient commit races
            if attempt == 2:
                print(f"Commit failed: {e}", file=sys.stderr)
                return 1
            print(f"  commit retry {attempt + 1}: {e}")
            time.sleep(5)

    print(f"DONE — versionCode {version_code} is now on '{args.track}'.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
