#!/bin/sh
# Takes screenshots of the iPhone app's main screens in the simulator, with staged content.
#
#   tools/screens.sh [output folder]      (default: build/screens)
#
# The simulator has no Bluetooth, so the app is launched with `-demo <screen>`, which stages a
# connected recorder; the notes come from a sample log written into the app's folder first.
set -e
cd "$(dirname "$0")/.."
out=${1:-build/screens}
device="iPhone 17"
mkdir -p "$out"
xcodebuild -project Quasi.xcodeproj -scheme QuasiPhone -configuration Debug -derivedDataPath build \
    -destination "platform=iOS Simulator,name=$device" build | grep -E "error|BUILD"
xcrun simctl boot "$device" 2>/dev/null || true
xcrun simctl bootstatus "$device" >/dev/null
xcrun simctl status_bar "$device" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3
xcrun simctl ui "$device" appearance light
xcrun simctl install "$device" build/Build/Products/Debug-iphonesimulator/QuasiPhone.app
data=$(xcrun simctl get_app_container "$device" com.alexisrondeau.Quasi data)
mkdir -p "$data/Documents/Recordings"
python3 tools/sample_log.py $SAMPLE > "$data/Documents/Recordings/log.json"     # SAMPLE=site for the web page's notes
for screen in home live note settings; do
    xcrun simctl terminate "$device" com.alexisrondeau.Quasi 2>/dev/null || true
    xcrun simctl launch "$device" com.alexisrondeau.Quasi -demo "$screen" >/dev/null
    sleep 4
    xcrun simctl io "$device" screenshot "$out/$screen.png" 2>/dev/null
done
xcrun simctl terminate "$device" com.alexisrondeau.Quasi 2>/dev/null || true
echo "Screens in $out"
