#!/usr/bin/env bash
set -euo pipefail

BUNDLE_ID="com.example.HandsOff"

defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true
rm -f "$HOME/Library/Preferences/${BUNDLE_ID}.plist"
tccutil reset Camera "$BUNDLE_ID"
