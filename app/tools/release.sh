#!/bin/sh
# Builds the Release app, notarizes it if credentials are stored, and installs it to /Applications.
# One-time setup for notarization:
#   xcrun notarytool store-credentials quasi --apple-id <apple id> --team-id HKQARCV8QZ
set -e
cd "$(dirname "$0")/.."
xcodebuild -project Quasi.xcodeproj -scheme Quasi -configuration Release -derivedDataPath build build | grep -E "error|BUILD"
APP=build/Build/Products/Release/Quasi.app

if xcrun notarytool history --keychain-profile quasi >/dev/null 2>&1; then
    ditto -c -k --keepParent "$APP" build/Quasi.zip
    xcrun notarytool submit build/Quasi.zip --keychain-profile quasi --wait
    xcrun stapler staple "$APP"
else
    echo "No notarization credentials stored (profile 'quasi'); installing without notarization."
fi

pkill -x Quasi || true
sleep 1
rm -rf /Applications/Quasi.app
ditto "$APP" /Applications/Quasi.app
open /Applications/Quasi.app
echo "Installed /Applications/Quasi.app"
