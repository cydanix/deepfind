#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

readonly APP_NAME="DeepFind"
readonly VERSION=$(cat version)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RELEASE_DIR="$SCRIPT_DIR/release"
readonly DMG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.dmg"

#------------------------------------------------------------------------------
# Stapling
#------------------------------------------------------------------------------
echo "==> Stapling ticket into '$DMG_PATH'..."
xcrun stapler staple "$DMG_PATH" \
  || err "Stapling failed."

echo "✅ Notarization complete! DMG ready for distribution: $DMG_PATH"
