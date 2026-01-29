#!/usr/bin/env bash
set -euo pipefail

config="${1:-}"
if [[ -z "$config" ]]; then
  echo "Usage: $(basename "$0") DEBUG|RELEASE" >&2
  exit 1
fi

"$(dirname "$0")/build.sh" "$config"
"$(dirname "$0")/relaunch.sh" "$config"
