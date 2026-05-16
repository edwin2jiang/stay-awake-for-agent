#!/bin/zsh

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_BUNDLE_NAME="Stay Awake for Agent"
APP_BUNDLE_PATH="$ROOT_DIR/dist/$APP_BUNDLE_NAME.app"
INFO_PLIST="$ROOT_DIR/Resources/Info.plist"
RELEASE_DIR="$ROOT_DIR/dist/release"
DMG_STAGING_DIR="$ROOT_DIR/dist/dmg-staging"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$INFO_PLIST")"
ARCHIVE_BASENAME="Stay-Awake-for-Agent-macOS-$VERSION"
ARCHIVE_PATH="$RELEASE_DIR/$ARCHIVE_BASENAME.zip"
DMG_PATH="$RELEASE_DIR/$ARCHIVE_BASENAME.dmg"
CHECKSUM_PATH="$RELEASE_DIR/SHA256SUMS.txt"

"$ROOT_DIR/Scripts/build-app.sh" release universal

chmod +x "$APP_BUNDLE_PATH/Contents/MacOS/StayAwakeForAgent"
chmod +x "$ROOT_DIR"/Scripts/*.sh
chmod +x "$ROOT_DIR"/Scripts/*.py

rm -rf "$RELEASE_DIR"
mkdir -p "$RELEASE_DIR"

cd "$ROOT_DIR/dist"
/usr/bin/ditto -c -k --keepParent "$APP_BUNDLE_NAME.app" "$ARCHIVE_PATH"

rm -rf "$DMG_STAGING_DIR"
mkdir -p "$DMG_STAGING_DIR"
cp -R "$APP_BUNDLE_PATH" "$DMG_STAGING_DIR/"
ln -s /Applications "$DMG_STAGING_DIR/Applications"

/usr/bin/hdiutil create \
    -volname "$APP_BUNDLE_NAME $VERSION" \
    -srcfolder "$DMG_STAGING_DIR" \
    -ov \
    -format UDZO \
    "$DMG_PATH" >/dev/null

rm -rf "$DMG_STAGING_DIR"

cd "$RELEASE_DIR"
/usr/bin/shasum -a 256 "$ARCHIVE_BASENAME.dmg" "$ARCHIVE_BASENAME.zip" > "$CHECKSUM_PATH"

echo "Created release artifacts:"
echo "$DMG_PATH"
echo "$ARCHIVE_PATH"
echo "$CHECKSUM_PATH"
echo "Version: $VERSION ($BUILD_NUMBER)"
