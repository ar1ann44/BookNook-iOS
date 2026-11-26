import SwiftUI

struct ClubDetailView: View {
    let clubId: Int
    var onChange: () -> Void = {}

    @Environment(SessionStore.self) private var session
    @State private var club: Club?
    @State private var errorMessage: String?
    @State private var memberToRemove: ClubMember?
    @State private var copiedCode = false

    var body: some View {
        List {
            if let club {
                header(club)
                if let book = club.currentBook {
                    Section("Currently reading") {
                        BookRow(book: book)
                    }
                }
                if club.isAdmin, let code = club.inviteCode {
                    inviteSection(code: code, clubName: club.name)
                }
                Section {
                    Label("Channels and chat are coming next.", systemImage: "bubble.left.and.bubble.right")
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Channels")
                }
                membersSection(club)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("Could not open this club", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Try again") { Task { await load() } }
                }
                .listRowBackground(Color.clear)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .overlay {
            if club == nil && errorMessage == nil { ProgressView() }
        }
        .navigationTitle(club?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await load() }
        .confirmationDialog(
            "Remove \(memberToRemove?.username ?? "")?",
            isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Remove from club", role: .destructive) { remove(member) }
        } message: { _ in
            Text("They will lose access to the club's channels. They can join again if the club is public or if they have the invite code.")
        }
    }

    private func header(_ club: Club) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Label(club.privacy.label, systemImage: club.privacy.systemImage)
                    if let count = club.members?.count {
                        Label("\(count) \(count == 1 ? "member" : "members")", systemImage: "person.2")
                    }
                    if club.isAdmin {
                        Label("You're an admin", systemImage: "star.fill")
                    }
                }
                .font(.caption.weight(.medium))
                .foregroundStyle(Theme.midnight)

                Text(club.name)
                    .font(Theme.heading(28))
                    .foregroundStyle(Theme.ink)

                if !club.description.isEmpty {
                    Text(club.description)
                        .font(Theme.body)
                        .foregroundStyle(Theme.ink.opacity(0.8))
                }
            }
            .padding(.vertical, 6)
        }
    }

    private func inviteSection(code: String, clubName: String) -> some View {
        Section {
            HStack {
                Text(code)
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.ink)
                    .textSelection(.enabled)
                Spacer()
                Button {
                    UIPasteboard.general.string = code
                    copiedCode = true
                } label: {
                    Image(systemName: copiedCode ? "checkmark" : "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Copy invite code")
                ShareLink(item: "Join my book club \"\(clubName)\" on BookNook with the code \(code)") {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Share invite code")
            }
        } header: {
            Text("Invite code")
        } footer: {
            Text("Only admins can see this code. Share it with people you want in the club.")
        }
    }

    private func membersSection(_ club: Club) -> some View {
        Section("Members") {
            ForEach(sortedMembers(club)) { member in
                HStack {
                    AvatarView(urlString: nil, name: member.username, size: 34)
                    Text(member.username)
                        .foregroundStyle(Theme.ink)
                    if member.id == session.user?.id {
                        Text("(you)").foregroundStyle(.secondary)
                    }
                    Spacer()
                    if member.role == .admin {
                        Text("Admin")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.midnight)
                    }
                }
                .swipeActions {
                    if canRemove(member, in: club) {
                        Button("Remove", role: .destructive) { memberToRemove = member }
                    }
                }
                .contextMenu {
                    if canRemove(member, in: club) {
                        Button("Remove from club", systemImage: "person.badge.minus", role: .destructive) {
                            memberToRemove = member
                        }
                    }
                }
            }
        }
    }

    private func sortedMembers(_ club: Club) -> [ClubMember] {
        (club.members ?? []).sorted {
            if $0.role != $1.role { return $0.role == .admin }
            return $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
        }
    }

    private func canRemove(_ member: ClubMember, in club: Club) -> Bool {
        club.isAdmin && member.id != session.user?.id
    }

    private func load() async {
        do {
            club = try await ClubService.club(id: clubId)
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func remove(_ member: ClubMember) {
        Task {
            do {
                try await ClubService.removeMember(clubId: clubId, userId: member.id)
                await load()
                onChange()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
