import SwiftUI

struct ProfileView: View {
    @Environment(SessionStore.self) private var session
    @State private var store = ProfileStore()
    @State private var isEditing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if let profile = store.profile {
                    ProfileContent(profile: profile)
                        .padding(20)
                } else if store.isLoading {
                    ProgressView().padding(.top, 80)
                } else if let error = store.errorMessage {
                    ContentUnavailableView {
                        Label("No se pudo cargar tu perfil", systemImage: "wifi.exclamationmark")
                    } description: {
                        Text(error)
                    } actions: {
                        Button("Reintentar") { Task { await store.load() } }
                    }
                }
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Perfil")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("Cerrar sesión", systemImage: "rectangle.portrait.and.arrow.right", role: .destructive) {
                            session.signOut()
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Editar") { isEditing = true }
                        .disabled(store.profile == nil)
                }
            }
            .refreshable { await store.load() }
            .task { await store.load() }
            .sheet(isPresented: $isEditing) {
                if let profile = store.profile {
                    EditProfileView(store: store, profile: profile)
                }
            }
        }
    }
}

private struct ProfileContent: View {
    let profile: Profile

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(spacing: 8) {
                AvatarView(urlString: profile.avatarUrl, name: profile.username, size: 110)
                Text(profile.username)
                    .font(Theme.heading(28))
                    .foregroundStyle(Theme.ink)
                if profile.bio.isEmpty {
                    Text("Aún no tienes biografía. Toca Editar para contarle a otros lectores sobre ti.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text(profile.bio)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink)
                        .multilineTextAlignment(.center)
                }
            }
            .frame(maxWidth: .infinity)

            SectionCard(title: "Géneros favoritos") {
                if profile.genres.isEmpty {
                    Text("Aún no eliges géneros.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    FlowLayout {
                        ForEach(profile.genres, id: \.self) { GenreChip(title: $0) }
                    }
                }
            }

            SectionCard(title: "Mis 4 libros favoritos") {
                FavoriteBooksGrid(books: profile.topBooks)
            }
        }
    }
}

struct FavoriteBooksGrid: View {
    let books: [Book]

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            ForEach(0..<Profile.maxTopBooks, id: \.self) { index in
                VStack(spacing: 6) {
                    if index < books.count {
                        let book = books[index]
                        BookCoverView(urlString: book.coverUrl, title: book.title, author: book.author, width: 72)
                        Text(book.title)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    } else {
                        RoundedRectangle(cornerRadius: 6)
                            .strokeBorder(Theme.locked, style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                            .frame(width: 72, height: 108)
                    }
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(Theme.heading(19))
                .foregroundStyle(Theme.ink)
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}
