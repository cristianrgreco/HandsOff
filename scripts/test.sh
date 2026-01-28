#!/usr/bin/env bash
set -euo pipefail

xcodebuild \
  -project HandsOff.xcodeproj \
  -scheme HandsOffTests \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  -enableCodeCoverage YES \
  test
