#!/usr/bin/env bash
set -euo pipefail

"$(dirname "$0")/build.sh"
"$(dirname "$0")/relaunch.sh"
