#!/usr/bin/env bash
set -euo pipefail

killall HandsOff || true

# Wait for the previous process to exit to avoid LaunchServices -600 during relaunch.
for _ in {1..20}; do
  if ! pgrep -x HandsOff >/dev/null; then
    break
  fi
  sleep 0.1
done

open -n .build/Build/Products/Debug/HandsOff.app
