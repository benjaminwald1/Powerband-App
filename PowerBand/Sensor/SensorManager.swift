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
}

/// Owns the connection to a PowerBand sensor. Until real hardware ships, the "Demo PowerBand" device streams simulated swings.
@Observable
@MainActor
final class SensorManager: NSObject {
    static let serviceUUID = CBUUID(string: "7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001")
    static let swingCharacteristicUUID = CBUUID(string: "7D1A0002-5B0E-4C1B-9A5B-0B6E7F3C0001")

    var state: SensorState = .idle
    var found: [FoundSensor] = []
    var battery: Int = 82
    var firmware = "0.9.4"
    var mount: Mount = .racquet
    var bluetoothAvailable = false
    var bluetoothNote = ""

    @ObservationIgnored private var central: CBCentralManager?
    @ObservationIgnored private var peripherals: [String: CBPeripheral] = [:]
    @ObservationIgnored private var active: CBPeripheral?
    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var onSwing: ((Swing) -> Void)?
    @ObservationIgnored private var usingDemo = false
    @ObservationIgnored private var generator = SwingGenerator()

    var isConnected: Bool { if case .connected = state { return true } else { return false } }
    var connectedName: String? { if case .connected(let n) = state { return n } else { return nil } }

    // MARK: Scanning

    func startScan() {
        found = [FoundSensor(id: "demo", name: "Demo PowerBand", isDemo: true)]
        state = .scanning
        if central == nil { central = CBCentralManager(delegate: self, queue: .main) }
        else if central?.state == .poweredOn { central?.scanForPeripherals(withServices: [Self.serviceUUID]) }
        Task { try? await Task.sleep(for: .seconds(6)); if state == .scanning { central?.stopScan(); state = .idle } }
    }

    func connect(_ s: FoundSensor) {
        central?.stopScan()
        state = .connecting(s.name)
        if s.isDemo {
            usingDemo = true
            Task { try? await Task.sleep(for: .milliseconds(900)); state = .connected(s.name); battery = 82 }
        } else if let p = peripherals[s.id] {
            usingDemo = false; active = p; p.delegate = self; central?.connect(p)
        }
    }

    func disconnect() {
        stopStream()
        if let p = active { central?.cancelPeripheralConnection(p) }
        active = nil; usingDemo = false; state = .idle
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
            case .poweredOn: bluetoothNote = ""; if state == .scanning { c.scanForPeripherals(withServices: [Self.serviceUUID]) }
            case .unauthorized: bluetoothNote = "Allow Bluetooth for PowerBand in Settings to connect a real sensor."
            case .unsupported: bluetoothNote = "Bluetooth isn't available on this device. The demo sensor still works."
            default: bluetoothNote = "Turn on Bluetooth to find your sensor."
            }
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didDiscover p: CBPeripheral, advertisementData: [String: Any], rssi: NSNumber) {
        MainActor.assumeIsolated {
            let name = p.name ?? (advertisementData[CBAdvertisementDataLocalNameKey] as? String) ?? "PowerBand"
            peripherals[p.identifier.uuidString] = p
            if !found.contains(where: { $0.id == p.identifier.uuidString }) { found.append(FoundSensor(id: p.identifier.uuidString, name: name, isDemo: false)) }
        }
    }

    nonisolated func centralManager(_ c: CBCentralManager, didConnect p: CBPeripheral) {
        MainActor.assumeIsolated { state = .connected(p.name ?? "PowerBand") }
        p.discoverServices([Self.serviceUUID])
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverServices error: Error?) {
        p.services?.forEach { p.discoverCharacteristics([Self.swingCharacteristicUUID], for: $0) }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didDiscoverCharacteristicsFor s: CBService, error: Error?) {
        s.characteristics?.forEach { p.setNotifyValue(true, for: $0) }
    }

    nonisolated func peripheral(_ p: CBPeripheral, didUpdateValueFor c: CBCharacteristic, error: Error?) {
        guard let data = c.value, let packet = SwingPacket.parse(data) else { return }
        MainActor.assumeIsolated { onSwing?(packet.swing(at: Date())) }
    }
}
