#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCT_NAME="StayAwakeForAgent"
APP_BUNDLE_NAME="Stay Awake for Agent"
CONFIGURATION="${1:-release}"
BUILD_ARCH="${2:-universal}"
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

build_for_triple() {
    local triple="$1"
    local scratch_path="$2"

    swift build \
        -c "$CONFIGURATION" \
        --product "$PRODUCT_NAME" \
        --triple "$triple" \
        --scratch-path "$scratch_path"

    swift build \
        -c "$CONFIGURATION" \
        --product "$PRODUCT_NAME" \
        --triple "$triple" \
        --scratch-path "$scratch_path" \
        --show-bin-path
}

case "$BUILD_ARCH" in
    universal)
        ARM64_BIN_DIR="$(build_for_triple "arm64-apple-macosx13.0" "$ROOT_DIR/.build/arm64-$CONFIGURATION" | tail -n 1)"
        X86_64_BIN_DIR="$(build_for_triple "x86_64-apple-macosx13.0" "$ROOT_DIR/.build/x86_64-$CONFIGURATION" | tail -n 1)"
        TEMP_EXECUTABLE="$DIST_DIR/$PRODUCT_NAME.universal"
        mkdir -p "$DIST_DIR"
        /usr/bin/lipo -create \
            "$ARM64_BIN_DIR/$PRODUCT_NAME" \
            "$X86_64_BIN_DIR/$PRODUCT_NAME" \
            -output "$TEMP_EXECUTABLE"
        EXECUTABLE_PATH="$TEMP_EXECUTABLE"
        ;;
    arm64)
        ARM64_BIN_DIR="$(build_for_triple "arm64-apple-macosx13.0" "$ROOT_DIR/.build/arm64-$CONFIGURATION" | tail -n 1)"
        EXECUTABLE_PATH="$ARM64_BIN_DIR/$PRODUCT_NAME"
        ;;
    x86_64)
        X86_64_BIN_DIR="$(build_for_triple "x86_64-apple-macosx13.0" "$ROOT_DIR/.build/x86_64-$CONFIGURATION" | tail -n 1)"
        EXECUTABLE_PATH="$X86_64_BIN_DIR/$PRODUCT_NAME"
        ;;
    native)
        swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME"
        BIN_DIR="$(swift build -c "$CONFIGURATION" --product "$PRODUCT_NAME" --show-bin-path)"
        EXECUTABLE_PATH="$BIN_DIR/$PRODUCT_NAME"
        ;;
    *)
        echo "Unknown build architecture: $BUILD_ARCH" >&2
        echo "Usage: $0 [debug|release] [universal|arm64|x86_64|native]" >&2
        exit 1
        ;;
esac

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
echo "Executable architecture:"
/usr/bin/lipo -archs "$APP_BUNDLE/Contents/MacOS/$PRODUCT_NAME"
