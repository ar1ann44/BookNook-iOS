import SwiftUI

struct RootView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        Group {
            if session.isRestoring {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
            } else if session.isSignedIn {
                MainTabView()
            } else {
                AuthFlowView()
            }
        }
        .task { await session.restore() }
    }
}
