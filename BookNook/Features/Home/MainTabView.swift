import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Feed", systemImage: "house") }

            ClubsView()
                .tabItem { Label("Clubs", systemImage: "person.3") }

            ProfileView()
                .tabItem { Label("Profile", systemImage: "person.crop.circle") }
        }
    }
}
