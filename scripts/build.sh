#!/usr/bin/env bash
set -euo pipefail

xcodebuild \
  -project HandsOff.xcodeproj \
  -scheme HandsOff \
  -configuration Debug \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  build
