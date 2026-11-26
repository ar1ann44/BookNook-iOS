import SwiftUI

struct ClubsView: View {
    @Environment(ToastCenter.self) private var toasts
    private enum Tab: String, CaseIterable, Identifiable {
        case mine = "Mis clubes"
        case discover = "Descubrir"
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
                Picker("Sección", selection: $tab) {
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
            .navigationTitle("Clubes")
            .navigationDestination(for: Int.self) { clubId in
                ClubDetailView(clubId: clubId, onChange: { Task { await load() } })
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Crear un club", systemImage: "plus") { showingCreate = true }
                        Button("Unirme con código", systemImage: "key") { showingJoinByCode = true }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .accessibilityLabel("Agregar club")
                }
            }
            .refreshable { await load() }
            .task { await load() }
            .sheet(isPresented: $showingCreate) {
                CreateClubView { club in
                    toasts.show("Club \(club.name) creado")
                    Task {
                        await load()
                        tab = .mine
                        path.append(club.id)
                    }
                }
            }
            .sheet(isPresented: $showingJoinByCode) {
                JoinByCodeView { clubId in
                    toasts.show("Te uniste al club")
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
                    Label("Aún no tienes clubes", systemImage: "person.3")
                } description: {
                    Text("Crea un club o descubre uno para unirte.")
                } actions: {
                    Button("Descubrir clubes") { tab = .discover }
                }
            } else if tab == .discover && publicClubs.isEmpty {
                ContentUnavailableView("Aún no hay clubes públicos", systemImage: "globe")
            }
        }
    }

    @ViewBuilder
    private func discoverRow(_ club: Club) -> some View {
        if club.isMember == true {
            NavigationLink(value: club.id) {
                ClubRow(club: club, trailingText: "Miembro")
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
                        Text("Unirme").fontWeight(.semibold)
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
                toasts.show("Te uniste a \(club.name)")
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
            BookCoverView(urlString: club.currentBook?.coverUrl, title: club.currentBook?.title, author: club.currentBook?.author, width: 44)
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
                    Text("Leyendo \(book.title)")
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
                        Label("\(count) \(count == 1 ? "miembro" : "miembros")", systemImage: "person.2")
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
