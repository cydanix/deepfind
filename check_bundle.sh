#!/usr/bin/env bash
set -e

VERSION=$(cat version)
APP="build/DeepFind.app"
DMG="release/DeepFind-${VERSION}.dmg"

echo "🔍  Verifying signature…"
codesign --verify --deep --strict --verbose=2 "$APP"

echo "📎  Checking stapled ticket…"
xcrun stapler validate "$DMG"

echo "🛡  Gatekeeper assessment…"
spctl --assess --type execute --verbose=4 "$APP"

echo "✅  All good."
