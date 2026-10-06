# PowerBand app

Native iPhone app (SwiftUI, iOS 17+) for the [PowerBand](https://powerband.fit) sensor: a coin-sized, screenless sensor that tracks swing speed, ball speed, racquet path, spin, contact point and shot count for tennis, pickleball, padel, golf and boxing.

## What's in it

- **Overview**: Power, Load and Form rings, shots today / total shots (count-up), speed chart, today's sessions
- **Live**: pick a sport, start a session, watch every shot arrive (speed, ball speed, spin, path, contact heat map)
- **History / Session detail**: per-session charts, racquet-face heat map, swing-path diagram, spin and punch breakdowns
- **Trends**: shots per day, personal bests, sport split
- **Device**: pair a sensor, mount type, band color
- **Account**: on-device profile (name, optional email), preferences, CSV export, Achievements, Privacy Policy / Terms of Service / support links, **Sign out** and **Delete account**
- On-device storage only. Nothing is uploaded. The account is a local profile: there is no server, password or cloud sync. Signing out keeps your sessions on the phone; deleting the account wipes the profile, all sessions and all settings.

## Sensor

There is no hardware yet, so the app ships with a **Demo PowerBand** that streams realistic simulated swings (`Sensor/SensorManager.swift`, `Models/SwingGenerator.swift`). Pair it from **Device > Scan for sensors**.

Real sensors connect over Bluetooth LE. The app scans for service `7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001` and subscribes to characteristic `7D1A0002-...` which notifies one 21-byte little-endian packet per swing. The layout is documented and unit tested in `Sensor/SwingPacket.swift`.

## Run on your iPhone (signing)

Signing settings live in a git-ignored file so your team ID never lands in the repo:

```bash
cp Local.xcconfig.example Local.xcconfig   # then put your Apple developer Team ID in it
xcodegen generate
```

Open `PowerBand.xcodeproj`, pick your iPhone and press Run. Xcode creates the provisioning profile for `com.benjaminwald.powerband` the first time.

## Bluetooth sensor

The app connects to a sensor over Bluetooth LE, remembers the last one, auto-reconnects (including after a dropout mid-session), reads battery and firmware, and keeps streaming while the screen is locked. The wire format is in [docs/SENSOR_PROTOCOL.md](docs/SENSOR_PROTOCOL.md). To test it with no hardware, run the Mac emulator in `Tools/SensorEmulator` and connect from a real iPhone (the iOS Simulator has no Bluetooth).

## TestFlight

See [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md) for the checklist, listing text and review notes, and `scripts/archive.sh` for building and uploading.

## Privacy and legal

- All sessions stay on the phone. The app has no accounts, analytics, ads or tracking, and `PowerBand/PrivacyInfo.xcprivacy` declares exactly that (the only required-reason API used is UserDefaults, `CA92.1`).
- Privacy Policy: https://powerband.fit/privacy/ and Terms of Service: https://powerband.fit/terms/. Both are linked from **Device > Legal** and from the last onboarding page. Use the privacy URL in App Store Connect.
- The legal text is a draft. It still has a placeholder for governing law (the support email is set), and it should be reviewed by a lawyer before launch.

## Build

```bash
brew install xcodegen   # once
xcodegen generate
open PowerBand.xcodeproj
```

Or from the command line:

```bash
xcodebuild -project PowerBand.xcodeproj -scheme PowerBand \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' CODE_SIGNING_ALLOWED=NO test
```

The Xcode project is generated from `project.yml`, so add new source files under `PowerBand/` and re-run `xcodegen generate`.
