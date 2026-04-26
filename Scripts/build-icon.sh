#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
ICON_SOURCE="$ROOT_DIR/Resources/AppIcon-1024.png"
ICONSET_DIR="$ROOT_DIR/Resources/AppIcon.iconset"
ICON_DEST="$ROOT_DIR/Resources/AppIcon.icns"

python3 "$ROOT_DIR/Scripts/generate-app-icon.py"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$ICON_SOURCE" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
    retina_size=$((size * 2))
    cp "$ICON_SOURCE" "$ICONSET_DIR/icon_${size}x${size}@2x.png"
    sips -z "$retina_size" "$retina_size" "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET_DIR" -o "$ICON_DEST"

echo "$ICON_DEST"
