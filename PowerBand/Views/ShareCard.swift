import SwiftUI

/// A branded summary card rendered to an image for sharing.
struct ShareCard: View {
    let session: Session
    let useMph: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("P").font(.system(size: 30, weight: .heavy).italic()).foregroundStyle(.white)
                Text("PowerBand").font(.system(size: 22, weight: .bold)).foregroundStyle(.white)
                Spacer()
                Text(session.start.formatted(.dateTime.month(.abbreviated).day())).font(.system(size: 14, weight: .semibold)).foregroundStyle(Theme.muted)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text(session.sport.title.uppercased()).font(.num(54)).foregroundStyle(.white)
                Text("\(durationText(session.duration)) session").font(.system(size: 14)).foregroundStyle(Theme.muted)
            }
            HStack(alignment: .top, spacing: 12) {
                tile("SHOTS", "\(session.count)", "")
                tile(session.sport.speedLabel.uppercased(), "\(Int(Units.speed(session.avgSpeed, useMph: useMph)))", Units.label(useMph: useMph))
                tile("BEST", "\(Int(Units.speed(session.maxSpeed, useMph: useMph)))", Units.label(useMph: useMph))
            }
            HStack(spacing: 12) {
                if session.sport.hasFace { tile("SWEET SPOT", "\(Int(session.sweetSpotRate * 100))", "%"); tile("AVG SPIN", session.avgSpin.formatted(), "rpm") }
                else if session.sport == .boxing { tile("PEAK FORCE", Int(session.maxForce).formatted(), "N"); tile("LOAD", String(format: "%.1f", session.load), "") }
                else { tile("TEMPO", String(format: "%.1f", session.avgTempo), ": 1"); tile("LOAD", String(format: "%.1f", session.load), "") }
            }
            Spacer(minLength: 0)
            Text("One sensor. More ways to play.  powerband.fit").font(.system(size: 12, weight: .medium)).foregroundStyle(Theme.muted)
        }
        .padding(26)
        .frame(width: 360, height: 450, alignment: .topLeading)
        .background(LinearGradient(colors: [Color(hex: 0x15191D), .black], startPoint: .top, endPoint: .bottom))
        .overlay(alignment: .topTrailing) { Circle().fill(Theme.green.opacity(0.18)).frame(width: 220).blur(radius: 50).offset(x: 70, y: -70) }
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }

    private func tile(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.system(size: 9, weight: .semibold)).tracking(1.4).foregroundStyle(Theme.muted)
            HStack(alignment: .firstTextBaseline, spacing: 2) { Text(value).font(.num(34)).foregroundStyle(.white); Text(unit).font(.system(size: 11)).foregroundStyle(Theme.muted) }
        }
        .frame(maxWidth: .infinity, alignment: .leading).padding(12)
        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
