# PowerBand app

Native iPhone app (SwiftUI, iOS 17+) for the [PowerBand](https://powerband.fit) sensor: a coin-sized, screenless sensor that tracks swing speed, ball speed, racquet path, spin, contact point and shot count for tennis, pickleball, padel, golf and boxing.

## What's in it

- **Overview**: Power, Load and Form rings, shots today / total shots (count-up), speed chart, today's sessions
- **Live**: pick a sport, start a session, watch every shot arrive (speed, ball speed, spin, path, contact heat map)
- **History / Session detail**: per-session charts, racquet-face heat map, swing-path diagram, spin and punch breakdowns
- **Trends**: shots per day, personal bests, sport split
- **Device**: pair a sensor, mount type, band color, units, CSV export, delete all data
- On-device storage only. Nothing is uploaded.

## Sensor

There is no hardware yet, so the app ships with a **Demo PowerBand** that streams realistic simulated swings (`Sensor/SensorManager.swift`, `Models/SwingGenerator.swift`). Pair it from **Device > Scan for sensors**.

Real sensors connect over Bluetooth LE. The app scans for service `7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001` and subscribes to characteristic `7D1A0002-...` which notifies one 21-byte little-endian packet per swing. The layout is documented and unit tested in `Sensor/SwingPacket.swift`.

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
