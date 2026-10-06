#!/usr/bin/env bash
# Finishes sign-in setup after you download GoogleService-Info.plist from the Firebase console.
#   1. Save the file as PowerBand/Resources/GoogleService-Info.plist
#   2. ./scripts/setup-auth.sh
# It writes the two URL schemes Google/Firebase need into Local.xcconfig (git-ignored) and regenerates the project.
set -euo pipefail
cd "$(dirname "$0")/.."
PLIST="PowerBand/Resources/GoogleService-Info.plist"
[ -f "$PLIST" ] || { echo "Missing $PLIST (download it from Firebase console > Project settings > Your apps > iOS)"; exit 1; }
APP_ID=$(/usr/libexec/PlistBuddy -c "Print :GOOGLE_APP_ID" "$PLIST")
REV=$(/usr/libexec/PlistBuddy -c "Print :REVERSED_CLIENT_ID" "$PLIST" 2>/dev/null || echo "")
BUNDLE=$(/usr/libexec/PlistBuddy -c "Print :BUNDLE_ID" "$PLIST")
[ "$BUNDLE" = "com.benjaminwald.powerband" ] || echo "Warning: plist bundle ID is $BUNDLE, expected com.benjaminwald.powerband"
SCHEME="app-$(echo "$APP_ID" | tr ':' '-')"
touch Local.xcconfig
grep -v -E '^(FIREBASE_APP_SCHEME|GOOGLE_REVERSED_CLIENT_ID)' Local.xcconfig > Local.xcconfig.tmp || true
{ cat Local.xcconfig.tmp; echo "FIREBASE_APP_SCHEME = $SCHEME"; echo "GOOGLE_REVERSED_CLIENT_ID = ${REV:-pb-google-unconfigured}"; } > Local.xcconfig
rm -f Local.xcconfig.tmp
xcodegen generate
echo "Done. FIREBASE_APP_SCHEME=$SCHEME  GOOGLE_REVERSED_CLIENT_ID=${REV:-n/a}"
