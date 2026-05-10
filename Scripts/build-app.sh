#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="StayAwakeForAgent"
APP_BUNDLE_NAME="Stay Awake for Agent"
CONFIGURATION="${1:-release}"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_BUNDLE_NAME.app"
ICON_PATH="$ROOT_DIR/Resources/AppIcon.icns"
HERO_BANNER_PATH="$ROOT_DIR/Resources/HeroBanner.png"

cd "$ROOT_DIR"

if [[ ! -f "$ICON_PATH" ]]; then
    "$ROOT_DIR/Scripts/build-icon.sh"
fi

if [[ ! -f "$HERO_BANNER_PATH" ]]; then
    python3 "$ROOT_DIR/Scripts/generate-hero-banner.py"
fi

swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"

BIN_DIR="$(swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$PRODUCT_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"

cp "$ROOT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp "$EXECUTABLE_PATH" "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"

if [[ -f "$ICON_PATH" ]]; then
    cp "$ICON_PATH" "$APP_BUNDLE/Contents/Resources/AppIcon.icns"
fi

if [[ -f "$HERO_BANNER_PATH" ]]; then
    cp "$HERO_BANNER_PATH" "$APP_BUNDLE/Contents/Resources/HeroBanner.png"
fi

chmod +x "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"

codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

echo "Built app bundle:"
echo "$APP_BUNDLE"
