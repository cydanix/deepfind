#!/bin/bash

ID=$1

# Check notarization status
xcrun notarytool info "$ID" \
    --apple-id $APPLE_ID \
    --team-id $TEAM_ID \
    --password "$APP_PASSWORD"

