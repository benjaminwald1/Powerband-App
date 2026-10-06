import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum Theme {
    static let bg = Color.black
    static let card = Color(hex: 0x101417)
    static let cardStroke = Color.white.opacity(0.07)
    static let green = Color(hex: 0x25E665)
    static let blue = Color(hex: 0x1C9BFF)
    static let slate = Color(hex: 0x7BA1BB)
    static let volt = Color(hex: 0xC6F432)
    static let red = Color(hex: 0xFF5A36)
    static let muted = Color(hex: 0x8A949C)
    static let track = Color.white.opacity(0.11)
}

extension Font {
    /// Bold condensed numerals used for every big number in the app.
    static func num(_ size: CGFloat) -> Font { .system(size: size, weight: .bold).width(.condensed) }
}

struct CardStyle: ViewModifier {
    var padding: CGFloat = 14
    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
    }
}

extension View {
    func card(padding: CGFloat = 14) -> some View { modifier(CardStyle(padding: padding)) }
}

/// Small letter-spaced grey label ("SHOTS TODAY").
struct Kicker: View {
    let text: String
    var color: Color = Theme.muted
    init(_ text: String, color: Color = Theme.muted) { self.text = text; self.color = color }
    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10, weight: .semibold))
            .tracking(1.5)
            .foregroundStyle(color)
    }
}

enum Units {
    static func speed(_ mph: Double, useMph: Bool) -> Double { useMph ? mph : mph * 1.609344 }
    static func label(useMph: Bool) -> String { useMph ? "mph" : "km/h" }
}
