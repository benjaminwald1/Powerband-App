import Foundation

/// 21-byte little-endian packet the PowerBand sensor notifies for every swing.
///
///  0  u32  timestamp (ms since sensor boot)
///  4  u8   sport (see `Sport.wireIndex`)
///  5  u8   shot kind index
///  6  u16  swing speed  (0.1 mph)
///  8  u16  ball speed   (0.1 mph)
/// 10  u16  spin (rpm)
/// 12  i16  path angle   (0.1 deg)
/// 14  i16  face angle   (0.1 deg)
/// 16  i8   impact X     (-127...127 = -1...1)
/// 17  i8   impact Y
/// 18  u8   tempo        (0.1)
/// 19  u16  force (N)
struct SwingPacket: Equatable {
    static let length = 21

    var sport: Sport, kindIndex: Int
    var swingMph: Double, ballMph: Double, spin: Int, path: Double, face: Double
    var impactX: Double, impactY: Double, tempo: Double, force: Double

    static func parse(_ d: Data) -> SwingPacket? {
        guard d.count >= length else { return nil }
        let b = [UInt8](d)
        func u16(_ i: Int) -> Int { Int(b[i]) | Int(b[i + 1]) << 8 }
        func i16(_ i: Int) -> Int { Int(Int16(bitPattern: UInt16(u16(i)))) }
        guard let sport = Sport.fromWire(Int(b[4])) else { return nil }
        return SwingPacket(sport: sport, kindIndex: Int(b[5]),
                           swingMph: Double(u16(6)) / 10, ballMph: Double(u16(8)) / 10, spin: u16(10),
                           path: Double(i16(12)) / 10, face: Double(i16(14)) / 10,
                           impactX: Double(Int8(bitPattern: b[16])) / 127, impactY: Double(Int8(bitPattern: b[17])) / 127,
                           tempo: Double(b[18]) / 10, force: Double(u16(19)))
    }

    func encode(timestampMs: UInt32 = 0) -> Data {
        var d = Data()
        func put16(_ v: Int) { d.append(UInt8(v & 0xFF)); d.append(UInt8((v >> 8) & 0xFF)) }
        for s in 0..<4 { d.append(UInt8((timestampMs >> UInt32(8 * s)) & 0xFF)) }
        d.append(UInt8(sport.wireIndex)); d.append(UInt8(kindIndex))
        put16(Int((swingMph * 10).rounded())); put16(Int((ballMph * 10).rounded())); put16(spin)
        put16(Int((path * 10).rounded()) & 0xFFFF); put16(Int((face * 10).rounded()) & 0xFFFF)
        d.append(UInt8(bitPattern: Int8((impactX * 127).rounded()))); d.append(UInt8(bitPattern: Int8((impactY * 127).rounded())))
        d.append(UInt8((tempo * 10).rounded())); put16(Int(force))
        return d
    }

    func swing(at date: Date) -> Swing {
        let kinds = sport.kinds
        return Swing(time: date, sport: sport, kind: kinds[min(kindIndex, kinds.count - 1)], swingMph: swingMph, ballMph: ballMph,
                     spinRpm: spin, pathDeg: path, faceDeg: face, impactX: impactX, impactY: impactY, tempo: tempo, forceN: force)
    }
}

extension Sport {
    var wireIndex: Int { Sport.allCases.firstIndex(of: self)! }
    static func fromWire(_ i: Int) -> Sport? { allCases.indices.contains(i) ? allCases[i] : nil }
}
