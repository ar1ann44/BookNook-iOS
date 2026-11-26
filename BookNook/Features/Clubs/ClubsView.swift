import SwiftUI

struct ClubsView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case mine = "My clubs"
        case discover = "Discover"
        var id: String { rawValue }
    }

    @State private var tab: Tab = .mine
    @State private var myClubs: [Club] = []
    @State private var publicClubs: [Club] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var path: [Int] = []
    @State private var showingCreate = false
    @State private var showingJoinByCode = false
    @State private var joiningClubId: Int?

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                switch tab {
                case .mine:
                    ForEach(myClubs) { club in
                        NavigationLink(value: club.id) { ClubRow(club: club) }
                    }
                case .discover:
                    ForEach(publicClubs) { club in
                        discoverRow(club)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .overlay { emptyState }
            .navigationTitle("Clubs")
            .navigationDestination(for: Int.self) { clubId in
                ClubDetailView(clubId: clubId, onChange: { Task { await load() } })
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Create a club", systemImage: "plus") { showingCreate = true }
                        Button("Join with a code", systemImage: "key") { showingJoinByCode = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Add club")
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showingCreate) {
                CreateClubView { club in
                    Task {
                        await load()
                        tab = .mine
                        path.append(club.id)
                    }
                }
            }
            .sheet(isPresented: $showingJoinByCode) {
                JoinByCodeView { clubId in
                    Task {
                        await load()
                        tab = .mine
                        path.append(clubId)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if isLoading && myClubs.isEmpty && publicClubs.isEmpty {
            ProgressView()
        } else if !isLoading && errorMessage == nil {
            if tab == .mine && myClubs.isEmpty {
                ContentUnavailableView {
                    Label("No clubs yet", systemImage: "person.3")
                } description: {
                    Text("Create a club or discover one to join.")
                } actions: {
                    Button("Discover clubs") { tab = .discover }
                }
            } else if tab == .discover && publicClubs.isEmpty {
                ContentUnavailableView("No public clubs yet", systemImage: "globe")
            }
        }
    }

    @ViewBuilder
    private func discoverRow(_ club: Club) -> some View {
        if club.isMember == true {
            NavigationLink(value: club.id) {
                ClubRow(club: club, trailingText: "Joined")
            }
        } else {
            HStack {
                ClubRow(club: club)
                Button {
                    join(club)
                } label: {
                    if joiningClubId == club.id {
                        ProgressView()
                    } else {
                        Text("Join").fontWeight(.semibold)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.rosy)
                .disabled(joiningClubId != nil)
            }
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        do {
            async let mine = ClubService.myClubs()
            async let discover = ClubService.publicClubs()
            (myClubs, publicClubs) = try await (mine, discover)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
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

struct ClubRow: View {
    let club: Club
    var trailingText: String?

    var body: some View {
        HStack(spacing: 12) {
            BookCoverView(urlString: club.currentBook?.coverUrl, width: 44)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(club.name)
                        .font(Theme.body.weight(.semibold))
                        .foregroundStyle(Theme.ink)
                        .lineLimit(1)
                    Image(systemName: club.privacy.systemImage)
                        .font(.caption)
                        .foregroundStyle(Theme.moss)
                }
                if let book = club.currentBook {
                    Text("Reading \(book.title)")
                        .font(.subheadline)
                        .foregroundStyle(Theme.midnight)
                        .lineLimit(1)
                } else if !club.description.isEmpty {
                    Text(club.description)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                HStack(spacing: 8) {
                    if let count = club.memberCount {
                        Label("\(count) \(count == 1 ? "member" : "members")", systemImage: "person.2")
                    }
                    if club.isAdmin {
                        Label("Admin", systemImage: "star.fill")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if let trailingText {
                Text(trailingText)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.moss)
            }
        }
        .padding(.vertical, 4)
    }
}
