#!/usr/bin/env bash
# Builds a release archive and an App Store Connect export (IPA) of the PowerBand app.
#
#   ./scripts/archive.sh            # archive + export to build/export/
#   ./scripts/archive.sh 5          # same, with build number 5
#   UPLOAD=1 ./scripts/archive.sh   # also upload straight to App Store Connect / TestFlight
#
# Needs: xcodegen, your Team ID in Local.xcconfig, and an Apple Developer account signed in to Xcode
# (Xcode > Settings > Accounts). Exporting for the App Store needs a distribution certificate; Xcode will
# create one for you when run with -allowProvisioningUpdates (this script passes it only when ALLOW_PROVISIONING=1).
set -euo pipefail
cd "$(dirname "$0")/.."

BUILD_NUMBER="${1:-$(date +%y%m%d%H%M)}"
TEAM="$(grep -E '^DEVELOPMENT_TEAM' Local.xcconfig | sed 's/.*= *//' | tr -d ' ')"
[ -n "$TEAM" ] || { echo "Put DEVELOPMENT_TEAM in Local.xcconfig first (see Local.xcconfig.example)"; exit 1; }

PROV=()
[ "${ALLOW_PROVISIONING:-0}" = "1" ] && PROV=(-allowProvisioningUpdates)

xcodegen generate
mkdir -p build
cat > build/ExportOptions.plist <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>method</key><string>app-store-connect</string>
  <key>teamID</key><string>$TEAM</string>
  <key>signingStyle</key><string>automatic</string>
  <key>destination</key><string>$([ "${UPLOAD:-0}" = "1" ] && echo upload || echo export)</string>
  <key>uploadSymbols</key><true/>
</dict></plist>
PLIST

echo "Archiving build $BUILD_NUMBER..."
xcodebuild -project PowerBand.xcodeproj -scheme PowerBand -configuration Release \
  -destination 'generic/platform=iOS' -archivePath build/PowerBand.xcarchive \
  CURRENT_PROJECT_VERSION="$BUILD_NUMBER" "${PROV[@]}" archive

echo "Exporting..."
xcodebuild -exportArchive -archivePath build/PowerBand.xcarchive \
  -exportOptionsPlist build/ExportOptions.plist -exportPath build/export "${PROV[@]}"

echo "Done. Output in build/export/"
