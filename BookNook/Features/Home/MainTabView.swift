import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            ComingSoonView(title: "Feed", systemImage: "house")
                .tabItem { Label("Feed", systemImage: "house") }

            ClubsView()
                .tabItem { Label("Clubs", systemImage: "person.3") }

            ProfileView()
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
