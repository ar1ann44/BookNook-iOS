import SwiftUI

struct FeedView: View {
    @Environment(SessionStore.self) private var session

    @State private var activity: [ActivityItem] = []
    @State private var myClubCount = 0
    @State private var discover: [Club] = []
    @State private var recommendations: Recommendations?
    @State private var hasLoaded = false
    @State private var errorMessage: String?
    @State private var joiningClubId: Int?
    @State private var selectedBook: Book?
    @State private var path: [Int] = []

    private static let maxDiscoverClubs = 6

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
                .padding(.vertical, 20)
            }
            .background(Theme.background.ignoresSafeArea())
            .overlay { if !hasLoaded { ProgressView() } }
            .navigationTitle("Feed")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: Int.self) { clubId in
                ClubDetailView(clubId: clubId, onChange: { Task { await load() } })
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(item: $selectedBook) { book in
                BookDetailSheet(book: book)
            }
        }
    }

    // MARK: Sections

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Hi, \(session.user?.username ?? "reader")")
                .font(Theme.heading(30))
                .foregroundStyle(Theme.ink)
            Text("Here's what's happening in your book clubs.")
                .font(Theme.body)
                .foregroundStyle(Theme.midnight)
        }
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var activitySection: some View {
        if hasLoaded {
            FeedSection(title: "Recent messages", systemImage: "bubble.left.and.bubble.right") {
                if myClubCount == 0 {
                    EmptyCard(text: "Join a club to see its latest conversations here.")
                } else if activity.isEmpty {
                    EmptyCard(text: "No messages yet. Start the conversation in one of your clubs!")
                } else {
                    VStack(spacing: 10) {
                        ForEach(activity) { item in
                            NavigationLink(value: item.clubId) {
                                ActivityCard(item: item)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private var discoverSection: some View {
        if !discover.isEmpty {
            FeedSection(title: "Clubs to discover", systemImage: "sparkles", titleInset: 20) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(discover) { club in
                            DiscoverClubCard(
                                club: club,
                                isJoining: joiningClubId == club.id,
                                onOpen: { path.append(club.id) },
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
            FeedSection(title: "Recommended books", systemImage: "books.vertical", titleInset: 20) {
                VStack(alignment: .leading, spacing: 18) {
                    if !recommendations.basedOnProfile {
                        Text("Add favorite genres to your profile to get recommendations picked for you.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 20)
                    }
                    ForEach(recommendations.sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(recommendations.basedOnProfile
                                 ? "Because you like \(section.genre)"
                                 : "Popular in \(section.genre)")
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
        async let activityResult = FeedService.activity(limit: 5)
        async let mineResult = ClubService.myClubs()
        async let publicResult = ClubService.publicClubs()
        async let recommendationsResult = FeedService.recommendations()

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

        // Recommendations depend on Google Books; the feed still works without them.
        recommendations = try? await recommendationsResult

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
                await load()
                path.append(club.id)
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

private struct ActivityCard: View {
    let item: ActivityItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            AvatarView(urlString: nil, name: item.username, size: 38)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.clubName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.moss)
                    Spacer()
                    Text(ServerDate.relative(item.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                Text(item.username)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.midnight)
                Text(item.content)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
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
                        BookCoverView(urlString: club.currentBook?.coverUrl, width: 46)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(club.name)
                                .font(Theme.body.weight(.semibold))
                                .foregroundStyle(Theme.ink)
                                .lineLimit(2)
                            if let count = club.memberCount {
                                Text("\(count) \(count == 1 ? "member" : "members")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    Text(club.currentBook.map { "Reading \($0.title)" } ?? club.description)
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
                    if isJoining { ProgressView().tint(.white) } else { Text("Join") }
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
            BookCoverView(urlString: book.coverUrl, width: 96)
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
                    BookCoverView(urlString: book.coverUrl, width: 140)
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
                        Text("No description available.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
            }
            .background(Theme.background.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
