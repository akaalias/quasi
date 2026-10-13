#!/bin/sh
# Archives the iPhone app and uploads it to TestFlight. The build number is the number of
# commits, so it only ever goes up. Signing is automatic: Xcode makes and keeps the distribution
# certificate and profile itself, through the Apple account signed in to Xcode (Xcode →
# Settings → Accounts), which is also what uploads. The App Store Connect key in .env is not
# needed here; tools/asc.sh uses it for what comes after the upload.
#
#   tools/testflight.sh               # archive and upload
#   tools/testflight.sh --no-upload   # archive only, to see that it builds
set -e
cd "$(dirname "$0")/.."
BUILD=$(git rev-list --count HEAD)
ARCHIVE=build/QuasiPhone.xcarchive

echo "Archiving build $BUILD..."
xcodebuild -project Quasi.xcodeproj -scheme QuasiPhone -configuration Release -destination "generic/platform=iOS" \
    -archivePath "$ARCHIVE" -derivedDataPath build CURRENT_PROJECT_VERSION="$BUILD" -allowProvisioningUpdates \
    archive | grep -E "error|warning: .*(sign|provision)|ARCHIVE"

[ "$1" = "--no-upload" ] && exit 0

cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>signingStyle</key><string>automatic</string>
	<key>teamID</key><string>HKQARCV8QZ</string>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict>
</plist>
PLIST
echo "Uploading…"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportOptionsPlist build/ExportOptions.plist -exportPath build/export \
    -allowProvisioningUpdates | grep -E "error|Upload|EXPORT"
echo "Build $BUILD is on its way to TestFlight; App Store Connect processes it for a few minutes."
