import Foundation
import CoreBluetooth
import Observation

enum SensorState: Equatable {
    case idle, scanning, connecting(String), connected(String)
}

struct FoundSensor: Identifiable, Equatable {
    let id: String
    let name: String
    let isDemo: Bool
    var rssi: Int? = nil
}

/// Owns the connection to a PowerBand sensor over Bluetooth LE.
///
/// GATT layout (see docs/SENSOR_PROTOCOL.md):
///  - PowerBand service  7D1A0001-...  with swing characteristic 7D1A0002-... (notify, one 21-byte packet per swing)
///  - Battery service    0x180F / 0x2A19 (read + notify)
///  - Device information 0x180A / 0x2A26 firmware revision (read)
///
/// Until hardware ships, "Demo PowerBand" streams simulated swings instead.
@Observable
@MainActor
final class SensorManager: NSObject {
    static let serviceUUID = CBUUID(string: "7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001")
    static let swingCharacteristicUUID = CBUUID(string: "7D1A0002-5B0E-4C1B-9A5B-0B6E7F3C0001")
    static let batteryService = CBUUID(string: "180F")
    static let batteryLevel = CBUUID(string: "2A19")
    static let deviceInfoService = CBUUID(string: "180A")
    static let firmwareRevision = CBUUID(string: "2A26")

    var state: SensorState = .idle
    var found: [FoundSensor] = []
    var battery: Int = 82
    var firmware = "0.9.4"
    var mount: Mount = .racquet
    var bluetoothAvailable = false
    var bluetoothNote = ""
    var errorNote = ""
    var rememberedName: String? { UserDefaults.standard.string(forKey: Keys.name) }

    private enum Keys { static let id = "lastSensorID", name = "lastSensorName" }

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripherals: [String: CBPeripheral] = [:]
    @ObservationIgnored private var active: CBPeripheral?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var onSwing: ((Swing) -> Void)?
    @ObservationIgnored private(set) var usingDemo = false
    @ObservationIgnored private var generator = SwingGenerator()
    @ObservationIgnored private var userDisconnected = false

    var isConnected: Bool { if case .connected = state { return true } else { return false } }
    var connectedName: String? { if case .connected(let n) = state { return n } else { return nil } }

    override init() {
        super.init()
        // Bring Bluetooth up at launch only if we have a sensor to reconnect to.
        if UserDefaults.standard.string(forKey: Keys.id) != nil { central = CBCentralManager(delegate: self, queue: .main) }
    }

    // MARK: Scanning and connecting

    func startScan() {
        errorNote = ""
        found = [FoundSensor(id: "demo", name: "Demo PowerBand", isDemo: true)]
        state = .scanning
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else if central?.state == .poweredOn { beginScanning() }
        Task { try? await Task.sleep(for: .seconds(12)); if state == .scanning { central?.stopScan(); state = .idle } }
    }

    private func beginScanning() {
        central?.scanForPeripherals(withServices: [Self.serviceUUID], options: [CBCentralManagerScanOptionAllowDuplicatesKey: false])
    }

    func connect(_ s: FoundSensor) {
        central?.stopScan()
        errorNote = ""
        userDisconnected = false
        state = .connecting(s.name)
        if s.isDemo {
            usingDemo = true
            Task { try? await Task.sleep(for: .milliseconds(900)); state = .connected(s.name); battery = 82 }
        } else if let p = peripherals[s.id] {
            usingDemo = false; connect(peripheral: p)
        }
    }

    private func connect(peripheral p: CBPeripheral) {
        active = p; p.delegate = self
        central?.connect(p)
        timeoutTask?.cancel()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(15))
            guard let self, !Task.isCancelled, case .connecting = self.state else { return }
            self.central?.cancelPeripheralConnection(p)
            self.state = .idle
            self.errorNote = "Couldn't reach the sensor. Tap it to wake it, keep it close, and try again."
        }
    }

    /// Reconnects to the last real sensor, if Bluetooth is on and we are idle.
    private func reconnectLast() {
        guard state == .idle, let c = central, c.state == .poweredOn,
              let idString = UserDefaults.standard.string(forKey: Keys.id), let id = UUID(uuidString: idString),
              let p = c.retrievePeripherals(withIdentifiers: [id]).first else { return }
        peripherals[idString] = p
        state = .connecting(p.name ?? rememberedName ?? "PowerBand")
        usingDemo = false
        connect(peripheral: p)
    }

    func disconnect(forget: Bool = false) {
        userDisconnected = true
        timeoutTask?.cancel()
        stopStream()
        if let p = active { central?.cancelPeripheralConnection(p) }
        active = nil; usingDemo = false; state = .idle
        if forget { UserDefaults.standard.removeObject(forKey: Keys.id); UserDefaults.standard.removeObject(forKey: Keys.name) }
    }

    // MARK: Streaming swings

    func startStream(sport: Sport, onSwing: @escaping (Swing) -> Void) {
        self.onSwing = onSwing
        generator = SwingGenerator()
        guard usingDemo else { return }   // a real sensor delivers swings through BLE notifications
        streamTask?.cancel()
        let started = Date()
        streamTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(Double.random(in: 1.4...3.0)))
                guard let self, !Task.isCancelled else { return }
                self.generator.fatigue = min(1, Date().timeIntervalSince(started) / 1800)
                self.onSwing?(self.generator.make(sport: sport, at: Date()))
            }
        }
    }

    func stopStream() { streamTask?.cancel(); streamTask = nil; onSwing = nil }
}

extension SensorManager: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ c: CBCentralManager) {
        MainActor.assumeIsolated {
            bluetoothAvailable = c.state == .poweredOn
            switch c.state {
            case .poweredOn:
                bluetoothNote = ""
                if state == .scanning { beginScanning() } else { reconnectLast() }
            case .unauthorized: bluetoothNote = "Allow Bluetooth for PowerBand in Settings to connect a real sensor."
            case .unsupported: bluetoothNote = "Bluetooth isn't available on this device. The demo sensor still works."
            default: bluetoothNote = "Turn on Bluetooth to find your sensor."
            }
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi RSSI: NSNumber) {
        MainActor.assumeIsolated {
            let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "PowerBand"
            let id = p.identifier.uuidString
            peripherals[id] = p
            if let i = found.firstIndex(where: { $0.id == id }) { found[i].rssi = RSSI.intValue }
            else { found.append(FoundSensor(id: id, name: name, isDemo: false, rssi: RSSI.intValue)) }
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        MainActor.assumeIsolated {
            timeoutTask?.cancel()
            let name = p.name ?? "PowerBand"
            state = .connected(name); errorNote = ""
            UserDefaults.standard.set(p.identifier.uuidString, forKey: Keys.id)
            UserDefaults.standard.set(name, forKey: Keys.name)
        }
        p.discoverServices([Self.serviceUUID, Self.batteryService, Self.deviceInfoService])
    }

    nonisolated func centralManager(_ c: CBCentralManager, didFailToConnect p: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            timeoutTask?.cancel(); state = .idle
            errorNote = "Couldn't connect: \(error?.localizedDescription ?? "unknown error")."
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didDisconnectPeripheral p: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated {
            guard !userDisconnected, !usingDemo else { return }
            if onSwing != nil {   // mid-session: keep trying so a brief dropout doesn't end the session
                state = .connecting(p.name ?? "PowerBand"); errorNote = "Connection dropped. Reconnecting…"
                c.connect(p)
            } else {
                state = .idle; errorNote = error == nil ? "" : "Sensor disconnected."
            }
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        p.services?.forEach { p.discoverCharacteristics(nil, for: $0) }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        for ch in s.characteristics ?? [] {
            switch ch.uuid {
            case Self.swingCharacteristicUUID: p.setNotifyValue(true, for: ch)
            case Self.batteryLevel: p.readValue(for: ch); p.setNotifyValue(true, for: ch)
            case Self.firmwareRevision: p.readValue(for: ch)
            default: break
            }
        }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard let data = c.value else { return }
        switch c.uuid {
        case Self.swingCharacteristicUUID:
            guard let packet = SwingPacket.parse(data) else { return }
            MainActor.assumeIsolated { onSwing?(packet.swing(at: Date())) }
        case Self.batteryLevel:
            if let b = data.first { MainActor.assumeIsolated { battery = Int(b) } }
        case Self.firmwareRevision:
            if let s = String(data: data, encoding: .utf8) { MainActor.assumeIsolated { firmware = s } }
        default: break
        }
    }
}
