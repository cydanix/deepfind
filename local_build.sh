#!/usr/bin/env bash
set -euo pipefail

CONFIG=${1:-Debug}

xcodebuild \
  -scheme DeepFind \
  -configuration $CONFIG \
  -destination 'platform=macOS' \
  -derivedDataPath ./build \
  build
