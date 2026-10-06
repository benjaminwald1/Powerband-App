// PowerBand sensor emulator for macOS.
//
// Advertises a fake PowerBand sensor over Bluetooth LE and notifies one swing packet every couple of seconds,
// so you can test the iPhone app's real Bluetooth path (scan, connect, battery, firmware, swing stream) with no hardware.
//
//   swiftc -O -o sensor-emulator Tools/SensorEmulator/main.swift -framework CoreBluetooth
//   ./sensor-emulator            # first run: allow Bluetooth for your terminal app when macOS asks
//
// Then on the iPhone: Device > Scan for sensors > "PowerBand Emulator" > Connect > Live > Start session.

import Foundation
import CoreBluetooth

let serviceUUID = CBUUID(string: "7D1A0001-5B0E-4C1B-9A5B-0B6E7F3C0001")
let swingUUID = CBUUID(string: "7D1A0002-5B0E-4C1B-9A5B-0B6E7F3C0001")
let batteryServiceUUID = CBUUID(string: "180F"), batteryUUID = CBUUID(string: "2A19")
let infoServiceUUID = CBUUID(string: "180A"), firmwareUUID = CBUUID(string: "2A26")

func gauss(_ mean: Double, _ sd: Double) -> Double {
    let u1 = Double.random(in: 0.0001...1), u2 = Double.random(in: 0...1)
    return mean + sd * (-2 * log(u1)).squareRoot() * cos(2 * .pi * u2)
}

/// 21-byte little-endian swing packet. Keep in sync with PowerBand/Sensor/SwingPacket.swift.
func packet(sport: UInt8, kind: UInt8, swing: Double, ball: Double, spin: Int, path: Double, face: Double, ix: Double, iy: Double, tempo: Double, force: Int, ms: UInt32) -> Data {
    var d = Data()
    func p16(_ v: Int) { d.append(UInt8(v & 0xFF)); d.append(UInt8((v >> 8) & 0xFF)) }
    for s in 0..<4 { d.append(UInt8((ms >> UInt32(8 * s)) & 0xFF)) }
    d.append(sport); d.append(kind)
    p16(Int((swing * 10).rounded())); p16(Int((ball * 10).rounded())); p16(spin)
    p16(Int((path * 10).rounded()) & 0xFFFF); p16(Int((face * 10).rounded()) & 0xFFFF)
    d.append(UInt8(bitPattern: Int8(max(-127, min(127, (ix * 127).rounded()))))); d.append(UInt8(bitPattern: Int8(max(-127, min(127, (iy * 127).rounded())))))
    d.append(UInt8((tempo * 10).rounded())); p16(force)
    return d
}

final class Emulator: NSObject, CBPeripheralManagerDelegate {
    var manager: CBPeripheralManager!
    var swingChar: CBMutableCharacteristic!
    var batteryChar: CBMutableCharacteristic!
    var timer: Timer?
    var subscribers = 0
    let boot = Date()
    var battery: UInt8 = 87

    override init() { super.init(); manager = CBPeripheralManager(delegate: self, queue: nil) }

    func peripheralManagerDidUpdateState(_ p: CBPeripheralManager) {
        print("Bluetooth state:", p.state.rawValue == 5 ? "poweredOn" : "raw \(p.state.rawValue)")
        guard p.state == .poweredOn else { return }
        swingChar = CBMutableCharacteristic(type: swingUUID, properties: [.notify], value: nil, permissions: [.readable])
        batteryChar = CBMutableCharacteristic(type: batteryUUID, properties: [.read, .notify], value: nil, permissions: [.readable])
        let fw = CBMutableCharacteristic(type: firmwareUUID, properties: [.read], value: Data("0.9.4-emu".utf8), permissions: [.readable])
        let main = CBMutableService(type: serviceUUID, primary: true); main.characteristics = [swingChar]
        let bat = CBMutableService(type: batteryServiceUUID, primary: false); bat.characteristics = [batteryChar]
        let info = CBMutableService(type: infoServiceUUID, primary: false); info.characteristics = [fw]
        [main, bat, info].forEach { p.add($0) }
        p.startAdvertising([CBAdvertisementDataLocalNameKey: "PowerBand Emulator", CBAdvertisementDataServiceUUIDsKey: [serviceUUID]])
        print("Advertising as \"PowerBand Emulator\". Waiting for the app to connect...")
    }

    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didSubscribeTo c: CBCharacteristic) {
        print("Subscribed:", c.uuid)
        if c.uuid == swingUUID { subscribers += 1; startStreaming() }
    }
    func peripheralManager(_ p: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom c: CBCharacteristic) {
        if c.uuid == swingUUID { subscribers = max(0, subscribers - 1); if subscribers == 0 { timer?.invalidate(); print("App disconnected") } }
    }
    func peripheralManager(_ p: CBPeripheralManager, didReceiveRead r: CBATTRequest) {
        if r.characteristic.uuid == batteryUUID { r.value = Data([battery]); p.respond(to: r, withResult: .success) }
        else { p.respond(to: r, withResult: .attributeNotFound) }
    }

    func startStreaming() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in self?.sendSwing() }
    }

    var count = 0
    func sendSwing() {
        count += 1
        let kind = UInt8.random(in: 0...3)          // tennis: forehand, backhand, serve, volley
        let base: Double = kind == 2 ? 92 : kind == 3 ? 48 : 68
        let swing = gauss(base, 7)
        var ix = gauss(0.04, 0.26), iy = gauss(-0.05, 0.26)
        let r = (ix * ix + iy * iy).squareRoot(); if r > 0.95 { ix *= 0.95 / r; iy *= 0.95 / r }
        let ms = UInt32(Date().timeIntervalSince(boot) * 1000)
        let d = packet(sport: 0, kind: kind, swing: swing, ball: swing * gauss(1.3, 0.05), spin: Int(gauss(2700, 380)), path: gauss(18, 4), face: gauss(-2, 3), ix: ix, iy: iy, tempo: gauss(2.9, 0.25), force: 0, ms: ms)
        let ok = manager.updateValue(d, for: swingChar, onSubscribedCentrals: nil)
        print("swing #\(count): \(Int(swing)) mph \(ok ? "sent" : "queued")")
        if count % 15 == 0 { battery = max(5, battery - 1); manager.updateValue(Data([battery]), for: batteryChar, onSubscribedCentrals: nil) }
    }
}

let emulator = Emulator()
_ = emulator
RunLoop.main.run()
