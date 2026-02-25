#!/bin/bash
set -euo pipefail

# One-click ad-hoc DMG packaging for Lookin internal testing.
# Output defaults:
#   DerivedData: /tmp/lookin-deriveddata
#   DMG dir:     /tmp/lookin-packages

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

WORKSPACE="${WORKSPACE:-Lookin.xcworkspace}"
SCHEME="${SCHEME:-LookinClient}"
CONFIGURATION="${CONFIGURATION:-Release}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-/tmp/lookin-deriveddata}"
OUTPUT_DIR="${OUTPUT_DIR:-/tmp/lookin-packages}"
VOLUME_NAME="${VOLUME_NAME:-Lookin}"

cd "$PROJECT_ROOT"

echo "[1/5] Building $SCHEME ($CONFIGURATION)..."
xcodebuild \
  -workspace "$WORKSPACE" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  build

APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/Lookin.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

echo "[2/5] Re-signing app (ad-hoc)..."
codesign --remove-signature "$APP_PATH" 2>/dev/null || true
codesign --force --deep --sign - "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo "[3/5] Preparing DMG staging..."
STAGE_DIR="$(mktemp -d /tmp/lookin-dmg-stage.XXXXXX)"
cp -R "$APP_PATH" "$STAGE_DIR/Lookin.app"
ln -s /Applications "$STAGE_DIR/Applications"

echo "[4/5] Creating DMG..."
mkdir -p "$OUTPUT_DIR"
DMG_PATH="$OUTPUT_DIR/Lookin-adhoc-$(date +%Y%m%d-%H%M).dmg"
hdiutil create -volname "$VOLUME_NAME" -srcfolder "$STAGE_DIR" -ov -format UDZO "$DMG_PATH"

echo "[5/5] Finalizing..."
rm -rf "$STAGE_DIR"
SHA256="$(shasum -a 256 "$DMG_PATH" | awk '{print $1}')"

ls -lh "$DMG_PATH"
echo "SHA256=$SHA256"
echo "DMG_PATH=$DMG_PATH"
