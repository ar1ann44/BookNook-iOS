import SwiftUI

struct ClubDetailView: View {
    let clubId: Int
    var onChange: () -> Void = {}

    @Environment(SessionStore.self) private var session
    @State private var club: Club?
    @State private var errorMessage: String?
    @State private var memberToRemove: ClubMember?
    @State private var copiedCode = false
    @State private var channels: [Channel] = []
    @State private var isJoining = false
    @State private var showingNewChannel = false
    @State private var newChannelName = ""
    @State private var showingNewPoll = false

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
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
                channelsSection(club)
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
        .toolbar {
            if club?.isAdmin == true {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("New channel", systemImage: "number") {
                            newChannelName = ""
                            showingNewChannel = true
                        }
                        Button("New book poll", systemImage: "chart.bar") { showingNewPoll = true }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Admin tools")
                }
            }
        }
        .alert("New channel", isPresented: $showingNewChannel) {
            TextField("Channel name", text: $newChannelName)
                .textInputAutocapitalization(.never)
            Button("Cancel", role: .cancel) {}
            Button("Create") { createChannel() }
        } message: {
            Text("Members will be able to chat in it right away.")
        }
        .sheet(isPresented: $showingNewPoll) {
            CreatePollView(clubId: clubId) { response in
                channels.append(response.channel)
            }
        }
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

    @ViewBuilder
    private func channelsSection(_ club: Club) -> some View {
        Section {
            if club.role == nil {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Join this club to read and write in its channels.")
                        .foregroundStyle(.secondary)
                    Button(action: join) {
                        if isJoining { ProgressView().tint(.white) } else { Text("Join club") }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(isJoining)
                }
                .padding(.vertical, 6)
            } else {
                ForEach(channels) { channel in
                    NavigationLink {
                        destination(for: channel)
                    } label: {
                        Label {
                            Text(channel.name).foregroundStyle(Theme.ink)
                        } icon: {
                            Image(systemName: channel.type == .poll ? "chart.bar.fill" : "number")
                                .foregroundStyle(channel.type == .poll ? Theme.rosy : Theme.midnight)
                        }
                    }
                }
            }
        } header: {
            Text("Channels")
        } footer: {
            if club.isAdmin {
                Text("Use the + button to add a channel or a book poll.")
            }
        }
    }

    @ViewBuilder
    private func destination(for channel: Channel) -> some View {
        if channel.type == .poll, let pollId = channel.pollId {
            PollView(clubId: clubId, pollId: pollId)
        } else {
            ChannelChatView(clubId: clubId, channel: channel)
        }
    }

    private func load() async {
        do {
            let loaded = try await ClubService.club(id: clubId)
            club = loaded
            channels = loaded.role == nil ? [] : try await ChannelService.channels(clubId: clubId)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func join() {
        isJoining = true
        Task {
            defer { isJoining = false }
            do {
                try await ClubService.join(clubId: clubId)
                await load()
                onChange()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func createChannel() {
        let name = newChannelName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            do {
                let channel = try await ChannelService.createChannel(clubId: clubId, name: name)
                channels.append(channel)
            } catch {
                errorMessage = error.localizedDescription
            }
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
