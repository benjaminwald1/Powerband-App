import SwiftUI

struct DeviceView: View {
    @Environment(Store.self) private var store
    @Environment(SensorManager.self) private var sensor
    @AppStorage("bandColor") private var bandColor = "Mocha"

    static let bands: [(name: String, color: Color)] = [
        ("Mocha", Color(hex: 0x6B4A3B)), ("Onyx", Color(hex: 0x2B2B2D)), ("Cognac", Color(hex: 0xB07A4A)), ("Navy", Color(hex: 0x2C3E6B)),
        ("Forest", Color(hex: 0x25503A)), ("Bordeaux", Color(hex: 0x6B2C3C)), ("Stone", Color(hex: 0xD7D4CF)), ("Sky", Color(hex: 0x6F94B8)),
    ]

    var body: some View {
        @Bindable var sensor = sensor
        Screen {
            ScreenHeader(kicker: sensor.isConnected ? "Connected" : "Not connected", title: "Device")

            if sensor.isConnected {
                HStack(spacing: 16) {
                    RingView(progress: Double(sensor.battery) / 100, color: sensor.battery > 20 ? Theme.green : Theme.red, value: "\(sensor.battery)%", label: "Battery", size: 92)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sensor.connectedName ?? "PowerBand").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                        Label("Firmware \(sensor.firmware)", systemImage: "cpu").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        Label("1,000 Hz sampling", systemImage: "waveform.path.ecg").font(.system(size: 12)).foregroundStyle(Theme.muted)
                        HStack {
                            Button("Disconnect") { sensor.disconnect() }.font(.system(size: 13, weight: .semibold)).buttonStyle(.bordered).tint(Theme.red)
                            Button("Forget") { sensor.disconnect(forget: true) }.font(.system(size: 13, weight: .semibold)).buttonStyle(.bordered).tint(Theme.muted)
                        }
                    }
                    Spacer()
                }
                .card()
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Pair your PowerBand").font(.system(size: 18, weight: .bold)).foregroundStyle(.white)
                    Text("Wake the sensor by tapping it, then scan. No real sensor yet? Connect the Demo PowerBand to try everything.").font(.system(size: 12)).foregroundStyle(Theme.muted)
                    Button { sensor.startScan() } label: {
                        HStack { if sensor.state == .scanning { ProgressView().tint(.black) }; Text(sensor.state == .scanning ? "Scanning…" : "Scan for sensors").font(.system(size: 15, weight: .bold)) }.frame(maxWidth: .infinity).padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent).tint(Theme.green).foregroundStyle(.black).disabled(sensor.state == .scanning)
                    if !sensor.bluetoothNote.isEmpty { Text(sensor.bluetoothNote).font(.system(size: 11)).foregroundStyle(Theme.muted) }
                    if !sensor.errorNote.isEmpty { Text(sensor.errorNote).font(.system(size: 11, weight: .medium)).foregroundStyle(Theme.red) }
                    if let last = sensor.rememberedName, sensor.state == .idle { Text("Last connected: \(last)").font(.system(size: 11)).foregroundStyle(Theme.muted) }
                    ForEach(sensor.found) { f in
                        Button { sensor.connect(f) } label: {
                            HStack { Image(systemName: f.isDemo ? "sparkles" : "dot.radiowaves.left.and.right").foregroundStyle(Theme.green)
                                Text(f.name).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white); Spacer()
                                if case .connecting(let n) = sensor.state, n == f.name { ProgressView() } else { HStack(spacing: 6) { if let r = f.rssi { Image(systemName: r > -60 ? "wifi" : r > -75 ? "wifi" : "wifi.exclamationmark").font(.system(size: 11)).foregroundStyle(Theme.muted) }; Text("Connect").font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.green) } } }
                            .padding(12).background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .card()
            }

            SectionLabel("MOUNT")
            VStack(spacing: 0) {
                ForEach(Mount.allCases) { m in
                    Button { sensor.mount = m } label: {
                        HStack { Text(m.rawValue).font(.system(size: 14, weight: .medium)).foregroundStyle(.white); Spacer()
                            if sensor.mount == m { Image(systemName: "checkmark.circle.fill").foregroundStyle(Theme.green) } }
                            .padding(.vertical, 11)
                    }
                    if m != Mount.allCases.last { Divider().overlay(Color.white.opacity(0.07)) }
                }
            }
            .card()

            SectionLabel("BAND COLOR")
            VStack(alignment: .leading, spacing: 10) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 8), spacing: 6) {
                    ForEach(Self.bands, id: \.name) { b in
                        Button { bandColor = b.name } label: {
                            Circle().fill(b.color).aspectRatio(1, contentMode: .fit)
                                .overlay(Circle().stroke(Color.white.opacity(0.25), lineWidth: 1))
                                .padding(2).overlay(Circle().stroke(bandColor == b.name ? Color.white : .clear, lineWidth: 2))
                        }
                    }
                }
                Text(bandColor).font(.system(size: 12, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading).card()
        }
    }
}
