#!/usr/bin/env bash
set -euo pipefail

# ─── Configuration ─────────────────────────────────────────────────────────────

APP_NAME="DeepFind"
APP_BUNDLE_ID="com.deepfind"

VERSION=$(cat version)
BUILD_DIR="build"
RELEASE_DIR="release"
SIGNING_IDENTITY="Developer ID Application: $DEV_ID_APPLICATION"

# ─── Helpers ───────────────────────────────────────────────────────────────────

error_exit() {
  echo "Error: $1" >&2
  exit 1
}

# ─── Verify prerequisites ──────────────────────────────────────────────────────

echo "Verifying code-signing identity: $SIGNING_IDENTITY"
if ! security find-identity -v -p codesigning | grep -q "$SIGNING_IDENTITY"; then
  error_exit "Signing identity '$SIGNING_IDENTITY' not found in keychain."
fi

# ─── Clean & prepare directories ───────────────────────────────────────────────

echo "Cleaning previous build and release dirs..."
rm -rf "$BUILD_DIR" "$RELEASE_DIR"
mkdir -p "$BUILD_DIR" "$RELEASE_DIR"

# ─── Build ─────────────────────────────────────────────────────────────────────

echo "Building $APP_NAME (release)…"
xcodebuild \
  -scheme DeepFind \
  -configuration Release \
  -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR" \
  build

# ─── Bundle creation ───────────────────────────────────────────────────────────

BUNDLE_PATH="$BUILD_DIR/$APP_NAME.app"
echo "Creating app bundle at '$BUNDLE_PATH'…"
mkdir -p "$BUNDLE_PATH/Contents/MacOS" "$BUNDLE_PATH/Contents/Resources"

echo "Copying executable into bundle…"
cp "$BUILD_DIR/Build/Products/Release/$APP_NAME" "$BUNDLE_PATH/Contents/MacOS/$APP_NAME"

echo "Copying icon file into bundle…"
cp "DeepFind.icns" "$BUNDLE_PATH/Contents/Resources/DeepFind.icns"

echo "Embedding mlx-swift bundle…"
cp -R "$BUILD_DIR/Build/Products/Release/mlx-swift_Cmlx.bundle" "$BUNDLE_PATH/Contents/Resources/mlx-swift_Cmlx.bundle"

echo "Copying Meilisearch binary into bundle…"
if [ -f "External/meilisearch" ]; then
    cp "External/meilisearch" "$BUNDLE_PATH/Contents/Resources/meilisearch"
    chmod +x "$BUNDLE_PATH/Contents/Resources/meilisearch"
    
    echo "Signing Meilisearch binary…"
    xcrun codesign --force \
                   --options runtime \
                   --timestamp \
                   --entitlements Meilisearch.entitlements \
                   --sign "$SIGNING_IDENTITY" \
                   --verbose=4 \
                   "$BUNDLE_PATH/Contents/Resources/meilisearch"
    
    echo "Verifying Meilisearch binary signature…"
    xcrun codesign --verify --verbose=4 "$BUNDLE_PATH/Contents/Resources/meilisearch"
else
    error_exit "Meilisearch binary not found at External/meilisearch. Run get_meilisearch_binary.sh first."
fi

echo "Copying third-party licenses into bundle…"
if [ -f "THIRD-PARTY-LICENSES" ]; then
    cp "THIRD-PARTY-LICENSES" "$BUNDLE_PATH/Contents/Resources/THIRD-PARTY-LICENSES"
else
    error_exit "THIRD-PARTY-LICENSES file not found. This file is required for legal compliance."
fi

echo "Writing Info.plist…"
cat > "$BUNDLE_PATH/Contents/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
         "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>${APP_BUNDLE_ID}</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundleVersion</key>
    <string>${VERSION}</string>
    <key>CFBundleShortVersionString</key>
    <string>${VERSION}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleIconFile</key>
    <string>DeepFind</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>NSHumanReadableCopyright</key>
    <string>© 2025 Cydanix LLC. All rights reserved.</string>
    <key>NSAppTransportSecurity</key>
    <dict>
        <key>NSAllowsArbitraryLoads</key>
        <true/>
        <key>NSExceptionDomains</key>
        <dict>
            <key>huggingface.co</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <false/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
            <key>hf.space</key>
            <dict>
                <key>NSExceptionAllowsInsecureHTTPLoads</key>
                <false/>
                <key>NSIncludesSubdomains</key>
                <true/>
            </dict>
        </dict>
    </dict>
</dict>
</plist>
EOF

# ─── Code-signing ───────────────────────────────────────────────────────────────

echo "Signing bundle with runtime options and entitlements…"
xcrun codesign --force \
               --options runtime \
               --deep \
               --timestamp \
               --entitlements DeepFind.entitlements \
               --sign "$SIGNING_IDENTITY" \
               --verbose=4 \
               "$BUNDLE_PATH"

echo "Verifying signature…"
xcrun codesign --verify --verbose=4 "$BUNDLE_PATH"

# ─── DMG packaging ─────────────────────────────────────────────────────────────

DMG_TEMP_DIR="$BUILD_DIR/dmg"
DMG_PATH="$RELEASE_DIR/${APP_NAME}-${VERSION}.dmg"

echo "Setting up DMG structure…"
mkdir -p "$DMG_TEMP_DIR"
cp -R "$BUNDLE_PATH" "$DMG_TEMP_DIR/"

echo "Creating DMG with custom layout…"
# Create temporary DMG
TEMP_DMG="$BUILD_DIR/temp.dmg"
hdiutil create -volname "${APP_NAME} ${VERSION}" \
               -srcfolder "$DMG_TEMP_DIR" \
               -ov \
               -format UDRW \
               "$TEMP_DMG"

# Mount the DMG
echo "Mounting DMG to configure layout…"
MOUNT_POINT="/Volumes/${APP_NAME} ${VERSION}"

# Ensure any previous mount is cleaned up
if [ -d "$MOUNT_POINT" ]; then
    echo "Unmounting existing DMG…"
    hdiutil detach "$MOUNT_POINT" 2>/dev/null || true
fi

hdiutil attach "$TEMP_DMG"

# Configure DMG window appearance with AppleScript
echo "Configuring DMG window layout…"
osascript << EOF
tell application "Finder"
    tell disk "${APP_NAME} ${VERSION}"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 72
        make new alias file at container window to POSIX file "/Applications" with properties {name:"Applications"}
        set position of item "${APP_NAME}.app" of container window to {150, 200}
        set position of item "Applications" of container window to {350, 200}
        close
        open
        update without registering applications
        delay 2
    end tell
end tell
EOF

# Unmount the DMG
echo "Unmounting DMG…"
hdiutil detach "$MOUNT_POINT"

# Convert to compressed DMG
echo "Converting to compressed DMG at '$DMG_PATH'…"
hdiutil convert "$TEMP_DMG" \
                -format UDZO \
                -imagekey zlib-level=9 \
                -o "$DMG_PATH"

# Clean up
rm "$TEMP_DMG"
rm -rf "$DMG_TEMP_DIR"

echo "✅ Build complete! DMG available at: $DMG_PATH"