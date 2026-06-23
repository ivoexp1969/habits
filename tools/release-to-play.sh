#!/usr/bin/env bash
# Build a signed release AAB and upload it to Google Play.
# Usage:  bash tools/release-to-play.sh [track]
#   track defaults to "internal". Use "alpha" for the default Closed-testing track,
#   or the exact custom Closed-testing track name from the Play Console.
#
# Requires android/key.properties (real signing values) and a Play service-account
# JSON at $PLAY_SA (override with the PLAY_SA env var).
set -euo pipefail

TRACK="${1:-internal}"
PLAY_SA="${PLAY_SA:-C:/Users/Admin/keys/play-service-account.json}"
AAB="build/app/outputs/bundle/release/app-release.aab"

if [ ! -f "$PLAY_SA" ]; then
  echo "ERROR: service-account JSON not found at: $PLAY_SA" >&2
  echo "Create it in Google Cloud + link in Play Console, then place it there." >&2
  exit 1
fi

echo ">> flutter build appbundle --release --no-tree-shake-icons"
flutter build appbundle --release --no-tree-shake-icons

echo ">> uploading $AAB to track '$TRACK'"
python tools/play_upload.py \
  --aab "$AAB" \
  --service-account "$PLAY_SA" \
  --track "$TRACK" \
  --notes-bg "Подобрения и нови функции." \
  --notes-en "Improvements and new features."
