#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/build"
DERIVED="$BUILD_DIR/DerivedData"
APP_NAME="present2md"
APP_PATH="$DERIVED/Build/Products/Release/$APP_NAME.app"
DMG_PATH="$ROOT/$APP_NAME.dmg"

echo "==> Cleaning previous build…"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Building $APP_NAME (Release)…"
xcodebuild \
    -project "$ROOT/$APP_NAME.xcodeproj" \
    -scheme  "$APP_NAME" \
    -configuration Release \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED" \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGN_STYLE=Manual \
    CODE_SIGNING_REQUIRED=YES \
    OTHER_CODE_SIGN_FLAGS="--deep" \
    build \
    | grep -E "^(Build|CompileSwift|error:|warning: build)" || true

if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed — $APP_PATH not found."
    exit 1
fi

echo "==> Creating DMG…"
STAGING="$BUILD_DIR/dmg_staging"
rm -rf "$STAGING"
mkdir -p "$STAGING"
cp -R "$APP_PATH" "$STAGING/"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
    -volname  "$APP_NAME" \
    -srcfolder "$STAGING" \
    -ov \
    -format UDZO \
    -fs HFS+ \
    "$DMG_PATH" > /dev/null

rm -rf "$STAGING"

echo ""
echo "✓ Done: $DMG_PATH"
echo ""
echo "Install:"
echo "  1. Open $APP_NAME.dmg"
echo "  2. Drag $APP_NAME.app → Applications"
echo "  3. First launch: right-click → Open (bypasses Gatekeeper for unsigned builds)"
