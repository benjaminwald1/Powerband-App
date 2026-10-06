# PowerBand sensor Bluetooth protocol (v1)

The app talks to the sensor over Bluetooth LE. This is the contract firmware must implement. The IDs are placeholders and can be changed in `PowerBand/Sensor/SensorManager.swift`; keep the sensor and the app in sync.

## Advertising

- Advertise the PowerBand service UUID `7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001` and a local name such as `PowerBand ••A1F2`.
- Advertise only after a tap or motion wake. Stop advertising while connected.

## GATT

| Service | UUID | Characteristic | UUID | Properties |
|---|---|---|---|---|
| PowerBand | `7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001` | Swing | `7D1A0002-5B0E-4C1B-9A5B-0B6E7F3C0001` | notify |
| Battery | `0x180F` | Battery level | `0x2A19` | read, notify (0-100) |
| Device information | `0x180A` | Firmware revision | `0x2A26` | read (UTF-8) |

## Swing packet (21 bytes, little-endian)

Sent as one notification per swing, within about 200 ms of contact.

| Offset | Type | Field | Unit |
|---|---|---|---|
| 0 | u32 | timestamp | ms since sensor boot |
| 4 | u8 | sport | 0 tennis, 1 pickleball, 2 padel, 3 golf, 4 boxing |
| 5 | u8 | shot kind | index into the sport's kinds (see `Sport.kinds`) |
| 6 | u16 | swing speed | 0.1 mph |
| 8 | u16 | ball speed | 0.1 mph (0 for boxing) |
| 10 | u16 | spin | rpm |
| 12 | i16 | path angle | 0.1 degree |
| 14 | i16 | face angle | 0.1 degree, negative = closed |
| 16 | i8 | impact X | -127...127 maps to -1...1 across the face |
| 17 | i8 | impact Y | -127...127 maps to -1...1 along the face |
| 18 | u8 | tempo | 0.1 (backswing : downswing) |
| 19 | u16 | force | newtons (boxing) |

Parsing and encoding are implemented and unit tested in `PowerBand/Sensor/SwingPacket.swift`.

## App behavior

- Scans only for the PowerBand service UUID, so it never lists unrelated devices.
- Remembers the last sensor and reconnects to it automatically at launch when Bluetooth is on.
- During a live session, a dropped connection is retried automatically so a brief dropout does not end the session.
- `UIBackgroundModes: bluetooth-central` lets the session keep receiving swings while the screen is locked.

## Testing without hardware

Run the emulator on a Mac (it advertises as `PowerBand Emulator` and streams tennis swings):

```bash
swiftc -O -o sensor-emulator Tools/SensorEmulator/main.swift -framework CoreBluetooth
./sensor-emulator
```

The iOS Simulator has no Bluetooth, so connect from a real iPhone.
