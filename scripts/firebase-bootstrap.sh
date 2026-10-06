#!/usr/bin/env bash
# One-shot Firebase setup for the PowerBand app. Run it after `npx firebase-tools login`.
#   ./scripts/firebase-bootstrap.sh [project-id]
# It creates the Firebase project (or reuses it), registers the iOS app, downloads GoogleService-Info.plist into the
# project and runs scripts/setup-auth.sh. Turning on the sign-in methods is still done once in the console (it prints the link).
set -euo pipefail
cd "$(dirname "$0")/.."
FB="npx -y firebase-tools@latest"
PROJECT="${1:-powerband-app-$(openssl rand -hex 2)}"
BUNDLE="com.benjaminwald.powerband"
PLIST="PowerBand/Resources/GoogleService-Info.plist"

$FB login:list | grep -q "Logged in as" || { echo "Not logged in. Run: npx firebase-tools login"; exit 1; }

if [ -f .firebaserc ]; then PROJECT="$(python3 -c "import json;print(json.load(open('.firebaserc'))['projects']['default'])")"; fi
if ! $FB projects:list 2>/dev/null | grep -q " $PROJECT "; then
  echo "Creating Firebase project $PROJECT ..."
  $FB projects:create "$PROJECT" --display-name "PowerBand"
fi
echo "{\"projects\":{\"default\":\"$PROJECT\"}}" > .firebaserc

APP_ID=$($FB apps:list IOS --project "$PROJECT" 2>/dev/null | grep "$BUNDLE" | grep -o '1:[0-9]*:ios:[0-9a-f]*' | head -1 || true)
if [ -z "$APP_ID" ]; then
  echo "Registering the iOS app ($BUNDLE) ..."
  $FB apps:create IOS "PowerBand" --bundle-id "$BUNDLE" --project "$PROJECT"
  APP_ID=$($FB apps:list IOS --project "$PROJECT" 2>/dev/null | grep "$BUNDLE" | grep -o '1:[0-9]*:ios:[0-9a-f]*' | head -1 || true)
  [ -n "$APP_ID" ] || { echo "Couldn't read the new app ID. Run: npx firebase-tools apps:list IOS --project $PROJECT"; exit 1; }
fi

mkdir -p PowerBand/Resources
$FB apps:sdkconfig IOS "$APP_ID" --project "$PROJECT" --out "$PLIST"
echo "Saved $PLIST"
./scripts/setup-auth.sh

cat <<MSG

Last manual step (about a minute): turn on the sign-in methods.
  https://console.firebase.google.com/project/$PROJECT/authentication/providers
  - Email/Password: enable
  - Google: enable (pick a support email)
  - Apple: enable
Then re-download the config so Google's redirect scheme is included, and rebuild:
  npx firebase-tools apps:sdkconfig IOS "$APP_ID" --project $PROJECT --out $PLIST && ./scripts/setup-auth.sh
Then build the app to your iPhone from Xcode once (this adds the Sign in with Apple capability to your App ID).
MSG
