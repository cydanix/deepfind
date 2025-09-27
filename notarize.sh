#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

#------------------------------------------------------------------------------
# Configuration (override via env or .env file)
#------------------------------------------------------------------------------

: "${APP_PASSWORD:?Environment variable APP_PASSWORD must be set (app-specific)}"

readonly APP_NAME="DeepFind"
readonly VERSION=$(cat version)
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RELEASE_DIR="$SCRIPT_DIR/release"
readonly DMG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.dmg"

#------------------------------------------------------------------------------
# Helpers
#------------------------------------------------------------------------------
function usage() {
  cat <<EOF
Usage: $(basename "$0") [options]

Options:
  -h            Show this help message and exit
EOF
  exit 0
}

function err() {
  echo "Error: $*" >&2
  exit 1
}

function check_command() {
  local cmd=$1
  if ! command -v "$cmd" &>/dev/null; then
    err "'$cmd' not found. Please install Xcode command-line tools."
  fi
}

#------------------------------------------------------------------------------
# Parse args
#------------------------------------------------------------------------------
while getopts "h" opt; do
  case $opt in
    h) usage ;;
    *) usage ;;
  esac
done

#------------------------------------------------------------------------------
# Pre-flight checks
#------------------------------------------------------------------------------
check_command xcrun
check_command stapler

[[ -f "$DMG_PATH" ]] || err "DMG not found at '$DMG_PATH'. Did you build it?"

#------------------------------------------------------------------------------
# Notarization
#------------------------------------------------------------------------------
echo "==> Submitting '$DMG_PATH' for notarization..."
xcrun notarytool submit "$DMG_PATH" \
  --apple-id    "$APPLE_ID" \
  --password    "$APP_PASSWORD" \
  --team-id     "$TEAM_ID" \
  || err "Notarization submission failed."
