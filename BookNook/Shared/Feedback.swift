import SwiftUI
import UIKit

/// Short confirmation banners ("Te uniste a …") shown at the top of the app.
@MainActor
@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let text: String
        let systemImage: String
    }

    private(set) var current: Toast?

    func show(_ text: String, systemImage: String = "checkmark.circle.fill") {
        let toast = Toast(text: text, systemImage: systemImage)
        withAnimation(.spring(duration: 0.35)) { current = toast }
        Haptics.success()
        Task {
            try? await Task.sleep(for: .seconds(2.2))
            if current?.id == toast.id {
                withAnimation(.easeOut(duration: 0.25)) { current = nil }
            }
        }
    }
}

struct ToastOverlay: ViewModifier {
    let center: ToastCenter

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let toast = center.current {
                Label(toast.text, systemImage: toast.systemImage)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Theme.ink.opacity(0.95))
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
                    .padding(.top, 8)
                    .padding(.horizontal, 20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .accessibilityAddTraits(.isStaticText)
            }
        }
    }
}

enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
}
