import SwiftUI

enum Theme {
    static let ink = Color(hex: 0x0A3323)
    static let moss = Color(hex: 0x839958)
    static let background = Color(hex: 0xF7F4D5)
    static let card = Color.white
    static let rosy = Color(hex: 0xD3968C)
    static let midnight = Color(hex: 0x105666)
    static let locked = Color(hex: 0xDED9BD)

    static func heading(_ size: CGFloat) -> Font {
        .system(size: size, weight: .semibold, design: .serif)
    }

    static let body = Font.system(.body, design: .serif)
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.rosy.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct FieldStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.locked, lineWidth: 1))
    }
}

extension View {
    func fieldStyle() -> some View { modifier(FieldStyle()) }
}
