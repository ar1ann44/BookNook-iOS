import SwiftUI

@main
struct BookNookApp: App {
    @State private var session = SessionStore()
    @State private var toasts = ToastCenter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(session)
                .environment(toasts)
                .modifier(ToastOverlay(center: toasts))
                .tint(Theme.midnight)
        }
    }
}
