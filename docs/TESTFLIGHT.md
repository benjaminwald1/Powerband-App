# TestFlight and App Store checklist

Everything below is prepared. The steps marked **You** need your Apple Developer account, so they can't be done from this repo.

## 1. One-time setup (You)

1. Enroll in the Apple Developer Program (developer.apple.com/programs) if the account isn't already paid and active.
2. In **App Store Connect > Apps > + > New App**:
   - Platform: iOS
   - Name: **PowerBand** (if taken, try "PowerBand: Sport Tracker")
   - Primary language: English (U.S.)
   - Bundle ID: `com.benjaminwald.powerband` (it appears once the App ID exists; the first Xcode Run or an archive with `ALLOW_PROVISIONING=1` creates it)
   - SKU: `powerband-ios`
3. Put your Team ID in `Local.xcconfig` (copy `Local.xcconfig.example`).

## 2. Build and upload

```bash
ALLOW_PROVISIONING=1 ./scripts/archive.sh            # archive + IPA in build/export/
ALLOW_PROVISIONING=1 UPLOAD=1 ./scripts/archive.sh   # archive and upload to TestFlight in one go
```

`ALLOW_PROVISIONING=1` lets Xcode create the distribution certificate and App Store profile in your account. Alternatively open `build/PowerBand.xcarchive` in Xcode's Organizer and press **Distribute App > TestFlight**.
Each upload needs a new build number: `./scripts/archive.sh 12`.

## 3. TestFlight information (paste into App Store Connect)

- **Beta App Description:** PowerBand tracks every swing from your PowerBand sensor in tennis, pickleball, padel, golf and boxing: swing speed, ball speed, spin, racquet path, contact point and shot count. No hardware yet? Use the built-in Demo PowerBand to try everything.
- **What to Test:** Pair the Demo PowerBand (Device > Scan for sensors > Demo PowerBand > Connect), start a Live session in each sport, end it, and check the session detail, History and Trends. Report anything confusing, slow or broken.
- **Feedback email:** `Benjaminwald11@gmail.com`
- **Beta App Review contact:** your name, phone, email.
- **Review notes:** "There is no server login: the app creates an on-device profile on first launch (tap Skip for now to bypass it). Sign out and Delete account are in the Account tab. The sensor hardware is not released yet, so the app includes a Demo PowerBand that streams simulated swings: Device tab > Scan for sensors > Demo PowerBand > Connect, then Live > Start session."
- **Export compliance:** the app only uses standard OS encryption (`ITSAppUsesNonExemptEncryption = false` is already set).

## 4. App Store listing (draft)

- **Subtitle:** Every swing, measured
- **Promotional text:** One sensor. More ways to play.
- **Description:**
  PowerBand turns every swing into data. Pair your PowerBand sensor and see swing speed, ball speed, spin, racquet path and exactly where the ball hit the face, for tennis, pickleball, padel, golf and boxing.

  - Live sessions with a running shot count
  - Power, Load and Form rings that show how today compares with your best
  - Sweet-spot heat maps and swing-path diagrams
  - History, trends and personal bests
  - Export every shot as CSV

  Your data stays on your phone. No account, no ads, no tracking.
- **Keywords:** tennis,pickleball,padel,golf,boxing,swing,sensor,speed,spin,tracker,training
- **Category:** Primary Health & Fitness, secondary Sports
- **Support URL:** https://powerband.fit (support email: Benjaminwald11@gmail.com)
- **Privacy Policy URL:** https://powerband.fit/privacy/
- **Terms of Use URL (optional):** https://powerband.fit/terms/
- **Age rating:** 4+ (no objectionable content)
- **Copyright:** 2026 PowerBand

## 5. App Privacy ("nutrition label") answers

The app collects no data off the device, so choose **Data Not Collected**. Tracking: **No**. This matches `PowerBand/PrivacyInfo.xcprivacy`.

## 6. Screenshots

6.9-inch iPhone screenshots (1320 x 2868) are in `AppStore/screenshots/`: onboarding, overview, history, trends, device. Regenerate them with the commands in `AppStore/README.md`.

## 7. Before you submit for public review

- Fill in the governing-law placeholder on the website terms page and have both legal pages reviewed.
- Test the real Bluetooth path on a phone using the Mac emulator (`docs/SENSOR_PROTOCOL.md`).
- A paid distribution account is needed for TestFlight and the App Store; TestFlight testers are invited by email or a public link.
