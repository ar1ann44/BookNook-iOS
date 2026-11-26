import SwiftUI

private enum FeedRoute: Hashable {
    case club(Int)
    case channel(Channel)
}

struct FeedView: View {
    @Environment(SessionStore.self) private var session
    @Environment(ToastCenter.self) private var toasts

    @State private var activity: [ClubActivity] = []
    @State private var myClubCount = 0
    @State private var discover: [Club] = []
    @State private var recommendations: Recommendations?
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var joiningClubId: Int?
    @State private var selectedBook: Book?
    @State private var path: [FeedRoute] = []

    private static let maxDiscoverClubs = 6
    private static let maxActivityClubs = 4

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    greeting

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }

                    activitySection
                    discoverSection
                    recommendationsSection
                }
                .padding(.top, 4)
                .padding(.bottom, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .overlay { if !hasLoaded { ProgressView() } }
            .navigationTitle("Inicio")
            .navigationDestination(for: FeedRoute.self) { route in
                switch route {
                case .club(let clubId):
                    ClubDetailView(clubId: clubId, onChange: { Task { await load() } })
                case .channel(let channel):
                    ChannelChatView(clubId: channel.clubId, channel: channel)
                }
            }
            .refreshable { await load() }
            // Runs again when coming back from a chat, so unread counts stay current.
            .onAppear { Task { await load() } }
            .sheet(item: $selectedBook) { book in
                BookDetailSheet(book: book)
            }
        }
    }

    // MARK: Sections

    private var greeting: some View {
        (Text("Hola, \(session.user?.username ?? "lector"). ").fontWeight(.semibold)
            + Text("Esto es lo que pasa en tus clubes de lectura."))
            .font(Theme.body)
            .foregroundStyle(Theme.midnight)
            .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var activitySection: some View {
        if hasLoaded {
            FeedSection(title: "Actividad en tus clubes", systemImage: "bubble.left.and.bubble.right") {
                if myClubCount == 0 {
                    EmptyCard(text: "Únete a un club para ver aquí sus conversaciones.")
                } else if activity.isEmpty {
                    EmptyCard(text: "Aún no hay mensajes. ¡Empieza la conversación en uno de tus clubes!")
                } else {
                    VStack(spacing: 10) {
                        if totalUnread == 0 {
                            Label("Estás al día con todos tus clubes.", systemImage: "checkmark.circle")
                                .font(.subheadline)
                                .foregroundStyle(Theme.moss)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        ForEach(visibleActivity) { item in
                            NavigationLink(value: FeedRoute.channel(item.channel)) {
                                ClubActivityCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    /// Clubs with unread messages first, then the most recently active ones.
    private var visibleActivity: [ClubActivity] {
        let unread = activity.filter { $0.unreadCount > 0 }
        let read = activity.filter { $0.unreadCount == 0 }
        return Array((unread + read).prefix(Self.maxActivityClubs))
    }

    private var totalUnread: Int {
        activity.reduce(0) { $0 + $1.unreadCount }
    }

    @ViewBuilder
    private var discoverSection: some View {
        if !discover.isEmpty {
            FeedSection(title: "Clubes para descubrir", systemImage: "sparkles", titleInset: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(discover) { club in
                            DiscoverClubCard(
                                club: club,
                                isJoining: joiningClubId == club.id,
                                onOpen: { path.append(.club(club.id)) },
                                onJoin: { join(club) }
                            )
                            .disabled(joiningClubId != nil)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    @ViewBuilder
    private var recommendationsSection: some View {
        if let recommendations, !recommendations.sections.isEmpty {
            FeedSection(title: "Libros recomendados", systemImage: "books.vertical", titleInset: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    if !recommendations.basedOnProfile {
                        Text("Agrega tus géneros favoritos en tu perfil para recibir recomendaciones hechas para ti.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                    ForEach(recommendations.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recommendations.basedOnProfile
                                 ? "Porque te gusta \(Genres.label(section.genre))"
                                 : "Populares en \(Genres.label(section.genre))")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.midnight)
                                .padding(.horizontal, 20)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(alignment: .top, spacing: 12) {
                                    ForEach(section.books, id: \.stableID) { book in
                                        Button { selectedBook = book } label: {
                                            RecommendedBookTile(book: book)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: Data

    private func load() async {
        async let activityResult = FeedService.clubActivity()
        async let mineResult = ClubService.myClubs()
        async let publicResult = ClubService.publicClubs()

        var firstError: Error?

        do {
            myClubCount = try await mineResult.count
            activity = try await activityResult
        } catch {
            firstError = firstError ?? error
        }

        do {
            discover = Array(
                try await publicResult
                    .filter { $0.isMember != true }
                    .prefix(Self.maxDiscoverClubs)
            )
        } catch {
            firstError = firstError ?? error
        }

        // Recommendations depend on Google Books; the feed still works without
        // them, and they're only fetched once per visit to keep calls low.
        if recommendations == nil {
            recommendations = try? await FeedService.recommendations()
        }

        if let firstError, !(firstError is CancellationError) {
            errorMessage = firstError.localizedDescription
        } else {
            errorMessage = nil
        }
        hasLoaded = true
    }

    private func join(_ club: Club) {
        joiningClubId = club.id
        Task {
            defer { joiningClubId = nil }
            do {
                try await ClubService.join(clubId: club.id)
                toasts.show("Te uniste a \(club.name)")
                await load()
                path.append(.club(club.id))
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

// MARK: - Building blocks

private struct FeedSection<Content: View>: View {
    let title: String
    let systemImage: String
    /// Carousels run edge to edge, so their section only insets the title.
    var titleInset: CGFloat = 0
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: systemImage)
                .font(Theme.heading(20))
                .foregroundStyle(Theme.ink)
                .padding(.horizontal, titleInset)
            content
        }
    }
}

private struct EmptyCard: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct ClubActivityCard: View {
    let item: ClubActivity

    private var hasUnread: Bool { item.unreadCount > 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(item.clubName)
                    .font(Theme.body.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Spacer()
                if hasUnread {
                    Text(item.unreadCount == 1 ? "1 nuevo" : "\(min(item.unreadCount, 99))\(item.unreadCount > 99 ? "+" : "") nuevos")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.rosy)
                        .clipShape(Capsule())
                } else {
                    Text(ServerDate.relative(item.latestMessage.createdAt))
                        .font(.caption2)
                        .foregroundStyle(Theme.ink.opacity(0.5))
                }
            }
            HStack(alignment: .top, spacing: 10) {
                AvatarView(urlString: item.latestMessage.avatarUrl, name: item.latestMessage.username, size: 28)
                VStack(alignment: .leading, spacing: 2) {
                    (Text(item.latestMessage.username).fontWeight(.semibold) + Text(": ") + Text(item.latestMessage.content))
                        .font(.subheadline)
                        .foregroundStyle(Theme.ink.opacity(hasUnread ? 1 : 0.7))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("#\(item.latestMessage.channelName)\(hasUnread ? " · " + ServerDate.relative(item.latestMessage.createdAt) : "")")
                        .font(.caption)
                        .foregroundStyle(Theme.midnight.opacity(0.8))
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.ink.opacity(0.3))
                    .padding(.top, 6)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(hasUnread ? Theme.rosy.opacity(0.6) : .clear, lineWidth: 1.5)
        )
        .accessibilityElement(children: .combine)
        .accessibilityHint("Abre el chat del club")
    }
}

private struct DiscoverClubCard: View {
    let club: Club
    let isJoining: Bool
    let onOpen: () -> Void
    let onJoin: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button(action: onOpen) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .top, spacing: 10) {
                        BookCoverView(urlString: club.currentBook?.coverUrl, title: club.currentBook?.title, author: club.currentBook?.author, width: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(club.name)
                                .font(Theme.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            if let count = club.memberCount {
                                Text("\(count) \(count == 1 ? "miembro" : "miembros")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text(club.currentBook.map { "Leyendo \($0.title)" } ?? club.description)
                        .font(.caption)
                        .foregroundStyle(Theme.midnight)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .buttonStyle(.plain)

            Spacer(minLength: 0)

            Button(action: onJoin) {
                Group {
                    if isJoining { ProgressView().tint(.white) } else { Text("Unirme") }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Theme.rosy)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(width: 220, height: 190)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

private struct RecommendedBookTile: View {
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookCoverView(urlString: book.coverUrl, title: book.title, author: book.author, width: 96)
            Text(book.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(2)
            Text(book.author)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 96, alignment: .leading)
    }
}

struct BookDetailSheet: View {
    let book: Book
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    BookCoverView(urlString: book.coverUrl, title: book.title, author: book.author, width: 140)
                        .shadow(radius: 6, y: 3)
                    VStack(spacing: 4) {
                        Text(book.title)
                            .font(Theme.heading(24))
                            .foregroundStyle(Theme.ink)
                            .multilineTextAlignment(.center)
                        Text(book.author)
                            .font(Theme.body)
                            .foregroundStyle(Theme.midnight)
                        if let year = book.publishedDate?.prefix(4), !year.isEmpty {
                            Text(year).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    if let categories = book.categories, !categories.isEmpty {
                        FlowLayout {
                            ForEach(categories, id: \.self) { GenreChip(title: $0) }
                        }
                    }
                    if let description = book.description, !description.isEmpty {
                        Text(description)
                            .font(Theme.body)
                            .foregroundStyle(Theme.ink)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Sin descripción disponible.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
