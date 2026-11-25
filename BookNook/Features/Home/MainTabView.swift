import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ComingSoonView(title: "Feed", systemImage: "house")
                .tabItem { Label("Feed", systemImage: "house") }

            ComingSoonView(title: "Clubs", systemImage: "person.3")
                .tabItem { Label("Clubs", systemImage: "person.3") }

            AccountPlaceholderView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}

private struct ComingSoonView: View {
    let title: String
    let systemImage: String

    var body: some View {
        NavigationStack {
            ContentUnavailableView(title, systemImage: systemImage, description: Text("Coming soon."))
                .background(Theme.background)
                .navigationTitle(title)
        }
    }
}

private struct AccountPlaceholderView: View {
    @Environment(SessionStore.self) private var session

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let user = session.user {
                    Text("Hi, \(user.username)!")
                        .font(Theme.heading(28))
                        .foregroundStyle(Theme.ink)
                    Text(user.email).foregroundStyle(.secondary)
                }
                Button("Log out", role: .destructive) { session.signOut() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
            .navigationTitle("Profile")
        }
    }
}
