#!/bin/bash
set -euo pipefail

PROJECT="Picly.xcodeproj"
SCHEME="Picly"
CONFIG="${1:-Debug}"

if [ "$CONFIG" != "Debug" ] && [ "$CONFIG" != "Release" ]; then
    echo "Usage: $0 [Debug|Release]"
    echo "  Default: Debug"
    exit 1
fi

# 杀掉旧 imageai 进程，释放端口
echo "=== Killing old imageai server ==="
OLD_PID=$(lsof -ti :8972 2>/dev/null || true)
if [ -n "$OLD_PID" ]; then
    kill "$OLD_PID" 2>/dev/null || true
    echo "  Killed PID $OLD_PID"
else
    echo "  No existing server on port 8972"
fi
echo ""

echo "=== Building Web Editor frontend ==="
IMAGEAI_DIR="/Users/lisheng/Workdir/imageai"
EDITOR_SCRIPT="$IMAGEAI_DIR/scripts/build-editor.sh"
if [ -f "$EDITOR_SCRIPT" ]; then
    bash "$EDITOR_SCRIPT"
else
    echo "  ⚠️  build-editor.sh not found, skipping Web Editor build"
fi
echo ""

echo "=== Building imageai (Release) ==="
pushd "$IMAGEAI_DIR" > /dev/null
swift build -c release 2>&1
popd > /dev/null
echo ""

echo "=== Copying imageai artifacts ==="
RESOURCES_DIR="Picly/Resources"

cp "$IMAGEAI_DIR/.build/release/imageai" "$RESOURCES_DIR/imageai"
echo "  Copied: $RESOURCES_DIR/imageai ($(du -sh "$RESOURCES_DIR/imageai" 2>/dev/null | cut -f1))"

IMAGEAI_BUNDLE="imageai_ImageAICLI.bundle"
BUNDLE_SRC="$IMAGEAI_DIR/.build/release/$IMAGEAI_BUNDLE"
if [ -d "$BUNDLE_SRC" ]; then
    rm -rf "$RESOURCES_DIR/$IMAGEAI_BUNDLE"
    cp -R "$BUNDLE_SRC" "$RESOURCES_DIR/$IMAGEAI_BUNDLE"
    echo "  Copied: $RESOURCES_DIR/$IMAGEAI_BUNDLE ($(du -sh "$RESOURCES_DIR/$IMAGEAI_BUNDLE" 2>/dev/null | cut -f1))"
else
    echo "  ⚠️  $IMAGEAI_BUNDLE not found at $BUNDLE_SRC"
fi

echo "=== Signing imageai binary ==="
codesign -f -s - "$RESOURCES_DIR/imageai"
echo "  Signed: $RESOURCES_DIR/imageai (ad-hoc)"
echo ""

echo "=== Building Picly ($CONFIG) ==="
echo ""

xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build

echo ""
echo "=== Done ==="

DERIVED_DIR="$HOME/Library/Developer/Xcode/DerivedData"
APP_NAME="Picly"
if [ "$CONFIG" == "Debug" ]; then
    APP_NAME="PiclyDbg"
fi

# Find the .app
APP_PATH=$(find "$DERIVED_DIR" -name "${APP_NAME}.app" -path "*/Build/Products/${CONFIG}/*" -maxdepth 6 2>/dev/null | head -1)

if [ -n "$APP_PATH" ]; then
    echo "  Product: $APP_PATH"
else
    echo "  (could not locate .app in DerivedData)"
fi
