#!/usr/bin/env bash
set -euo pipefail

"$(dirname "$0")/build_release.sh"
"$(dirname "$0")/relaunch_release.sh"
