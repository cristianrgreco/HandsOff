#!/usr/bin/env bash
set -euo pipefail

xcodebuild \
  -project HandsOff.xcodeproj \
  -scheme HandsOff \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  build
