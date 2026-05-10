#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE_PATH="$ROOT_DIR/dist/Stay Awake for Agent.app"

"$ROOT_DIR/Scripts/stop-app.sh"
"$ROOT_DIR/Scripts/build-app.sh"
open "$APP_BUNDLE_PATH"

echo "Restarted:"
echo "$APP_BUNDLE_PATH"
