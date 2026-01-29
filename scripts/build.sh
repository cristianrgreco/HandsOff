#!/usr/bin/env bash
set -euo pipefail

config="${1:-}"
if [[ -z "$config" ]]; then
  echo "Usage: $(basename "$0") DEBUG|RELEASE" >&2
  exit 1
fi

config_upper="$(printf '%s' "$config" | tr '[:lower:]' '[:upper:]')"
case "$config_upper" in
  DEBUG) configuration="Debug" ;;
  RELEASE) configuration="Release" ;;
  *)
    echo "Invalid configuration: $config. Use DEBUG or RELEASE." >&2
    exit 1
    ;;
esac

xcodebuild \
  -project HandsOff.xcodeproj \
  -scheme HandsOff \
  -configuration "$configuration" \
  -destination 'platform=macOS' \
  -derivedDataPath .build \
  build
