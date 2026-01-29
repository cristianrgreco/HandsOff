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

killall HandsOff || true

# Wait for the previous process to exit to avoid LaunchServices -600 during relaunch.
for _ in {1..20}; do
  if ! pgrep -x HandsOff >/dev/null; then
    break
  fi
  sleep 0.1
done

open -n ".build/Build/Products/${configuration}/HandsOff.app"
