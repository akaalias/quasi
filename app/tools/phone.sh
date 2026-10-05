#!/bin/sh
# Builds the iPhone app and installs and launches it on the connected iPhone (unlocked, developer mode on).
# The Mac app must not be running: only one client can hold the recorder.
# ANTHROPIC_API_KEY and TODOIST_API_TOKEN from the repository's .env, if present, are handed to
# the app at launch, which stores them in the phone's keychain.
set -e
cd "$(dirname "$0")/.."
DEVICE=$(xcrun xctrace list devices 2>/dev/null | sed -n '/== Devices ==/,/== Simulators ==/p' | grep iPhone | head -1 | sed -E 's/.*\(([0-9A-F-]+)\)$/\1/')
[ -n "$DEVICE" ] || { echo "No iPhone connected."; exit 1; }
xcodebuild -project Quasi.xcodeproj -scheme QuasiPhone -configuration Debug -derivedDataPath build \
    -destination "id=$DEVICE" -allowProvisioningUpdates build | grep -E "error|BUILD"
xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Debug-iphoneos/QuasiPhone.app >/dev/null
ENVIRONMENT=$(python3 - <<'PY'
import json, os
values = {}
path = os.path.join("..", ".env")
if os.path.exists(path):
    for line in open(path):
        name, _, value = line.strip().partition("=")
        if name in ("ANTHROPIC_API_KEY", "TODOIST_API_TOKEN") and value:
            values[name] = value.strip("\"'")
print(json.dumps(values))
PY
)
xcrun devicectl device process launch --terminate-existing --device "$DEVICE" \
    --environment-variables "$ENVIRONMENT" com.alexisrondeau.Quasi | tail -1
