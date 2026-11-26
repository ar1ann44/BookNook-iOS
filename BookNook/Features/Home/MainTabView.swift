import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            FeedView()
                .tabItem { Label("Inicio", systemImage: "house") }

            ClubsView()
                .tabItem { Label("Clubes", systemImage: "person.3") }

            ProfileView()
                .tabItem { Label("Perfil", systemImage: "person.crop.circle") }
        }
    }
}
