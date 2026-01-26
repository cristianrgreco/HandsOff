#!/usr/bin/env bash
set -euo pipefail

killall HandsOff || true
open .build/Build/Products/Debug/HandsOff.app
