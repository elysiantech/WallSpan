#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/.build"
APP_NAME="WallSpan"
APP_BUNDLE="$PROJECT_DIR/$APP_NAME.app"

echo "Building $APP_NAME..."
cd "$PROJECT_DIR"
swift build -c release

echo "Creating app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy binary
cp "$BUILD_DIR/release/$APP_NAME" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# Copy Info.plist
cp "$PROJECT_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/"

# Ad-hoc sign so macOS doesn't complain on the local machine
codesign --force --sign - "$APP_BUNDLE"

# Generate checksum
CHECKSUM=$(shasum -a 256 "$APP_BUNDLE/Contents/MacOS/$APP_NAME")
echo "$CHECKSUM" > "$PROJECT_DIR/CHECKSUMS.sha256"

echo ""
echo "Built: $APP_BUNDLE"
echo "SHA-256: $CHECKSUM"
echo ""
echo "To run:  open $APP_BUNDLE"
echo "To verify: shasum -a 256 -c CHECKSUMS.sha256"
echo "To install: cp -r $APP_BUNDLE /Applications/"
