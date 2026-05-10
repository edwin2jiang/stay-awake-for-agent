#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="StayAwakeForAgent"
APP_BUNDLE_NAME="Stay Awake for Agent"
APP_BUNDLE_PATH="$ROOT_DIR/dist/$APP_BUNDLE_NAME.app"
EXECUTABLE_PATH="$APP_BUNDLE_PATH/Contents/MacOS/$PRODUCT_NAME"
BUNDLE_IDENTIFIER="com.edwin.stayawakeforagent"

terminate_matching_processes() {
    local signal="$1"
    local matches=""

    matches="$(pgrep -fl "$EXECUTABLE_PATH" || true)"
    if [[ -n "$matches" ]]; then
        echo "$matches" | awk '{print $1}' | xargs -r kill "-$signal"
    fi

    matches="$(pgrep -x "$PRODUCT_NAME" || true)"
    if [[ -n "$matches" ]]; then
        echo "$matches" | xargs -r kill "-$signal"
    fi
}

/usr/bin/osascript -e "tell application id \"$BUNDLE_IDENTIFIER\" to quit" >/dev/null 2>&1 || true

terminate_matching_processes TERM

for _ in {1..20}; do
    if ! pgrep -f "$EXECUTABLE_PATH" >/dev/null 2>&1 && ! pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
        echo "Stopped existing $APP_BUNDLE_NAME processes."
        exit 0
    fi
    sleep 0.2
done

terminate_matching_processes KILL
sleep 0.2

if ! pgrep -f "$EXECUTABLE_PATH" >/dev/null 2>&1 && ! pgrep -x "$PRODUCT_NAME" >/dev/null 2>&1; then
    echo "Force-stopped existing $APP_BUNDLE_NAME processes."
    exit 0
fi

echo "Failed to stop all $APP_BUNDLE_NAME processes." >&2
exit 1
