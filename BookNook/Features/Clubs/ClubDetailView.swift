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
        ScrollView {
            if let club {
                VStack(alignment: .leading, spacing: 16) {
                    header(club)
                    if let book = club.currentBook {
                        SectionCard(title: "Leyendo ahora") {
                            BookRow(book: book)
                        }
                    }
                    if club.isAdmin, let code = club.inviteCode {
                        inviteCard(code: code, clubName: club.name)
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.red)
                    }
                    channelsCard(club)
                    membersCard(club)
                }
                .padding(20)
            } else if let errorMessage {
                ContentUnavailableView {
                    Label("No se pudo abrir el club", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("Reintentar") { Task { await load() } }
                }
                .padding(.top, 60)
            }
        }
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
                        Button("Nuevo canal", systemImage: "number") {
                            newChannelName = ""
                            showingNewChannel = true
                        }
                        Button("Nueva encuesta", systemImage: "chart.bar") { showingNewPoll = true }
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Herramientas de administrador")
                }
            }
        }
        .alert("Nuevo canal", isPresented: $showingNewChannel) {
            TextField("Nombre del canal", text: $newChannelName)
                .textInputAutocapitalization(.never)
            Button("Cancelar", role: .cancel) {}
            Button("Crear") { createChannel() }
        } message: {
            Text("Los miembros podrán escribir en él de inmediato.")
        }
        .sheet(isPresented: $showingNewPoll) {
            CreatePollView(clubId: clubId) { response in
                channels.append(response.channel)
            }
        }
        .confirmationDialog(
            "¿Quitar a \(memberToRemove?.username ?? "")?",
            isPresented: Binding(
                get: { memberToRemove != nil },
                set: { if !$0 { memberToRemove = nil } }
            ),
            titleVisibility: .visible,
            presenting: memberToRemove
        ) { member in
            Button("Quitar del club", role: .destructive) { remove(member) }
        } message: { _ in
            Text("Perderá acceso a los canales del club. Podrá volver a unirse si el club es público o si tiene el código de invitación.")
        }
    }

    // MARK: Cards

    private func header(_ club: Club) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Pill(text: club.privacy.label, systemImage: club.privacy.systemImage)
                if let count = club.members?.count {
                    Pill(text: "\(count) \(count == 1 ? "miembro" : "miembros")", systemImage: "person.2")
                }
                if club.isAdmin {
                    Pill(text: "Admin", systemImage: "star.fill")
                }
            }

            Text(club.name)
                .font(Theme.heading(28))
                .foregroundStyle(Theme.ink)

            if !club.description.isEmpty {
                Text(club.description)
                    .font(Theme.body)
                    .foregroundStyle(Theme.ink.opacity(0.8))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func inviteCard(code: String, clubName: String) -> some View {
        SectionCard(title: "Código de invitación") {
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
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Copiar código")
                ShareLink(item: "Únete a mi club de lectura \"\(clubName)\" en BookNook con el código \(code)") {
                    Image(systemName: "square.and.arrow.up")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Compartir código")
            }
            Text("Solo los administradores ven este código. Compártelo con quien quieras invitar.")
                .font(.footnote)
                .foregroundStyle(Theme.ink.opacity(0.6))
        }
    }

    @ViewBuilder
    private func channelsCard(_ club: Club) -> some View {
        SectionCard(title: "Canales") {
            if club.role == nil {
                Text("Únete a este club para leer y escribir en sus canales.")
                    .foregroundStyle(Theme.ink.opacity(0.7))
                Button(action: join) {
                    if isJoining { ProgressView().tint(.white) } else { Text("Unirme al club") }
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isJoining)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(channels.enumerated()), id: \.element.id) { index, channel in
                        if index > 0 { Divider() }
                        NavigationLink {
                            destination(for: channel)
                        } label: {
                            ChannelRow(channel: channel)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if club.isAdmin {
                    Text("Usa el botón + de arriba para crear un canal o una encuesta.")
                        .font(.footnote)
                        .foregroundStyle(Theme.ink.opacity(0.6))
                }
            }
        }
    }

    private func membersCard(_ club: Club) -> some View {
        SectionCard(title: "Miembros") {
            VStack(spacing: 0) {
                ForEach(Array(sortedMembers(club).enumerated()), id: \.element.id) { index, member in
                    if index > 0 { Divider() }
                    HStack(spacing: 12) {
                        AvatarView(urlString: nil, name: member.username, size: 34)
                        Text(member.username)
                            .foregroundStyle(Theme.ink)
                        if member.id == session.user?.id {
                            Text("(tú)").foregroundStyle(Theme.ink.opacity(0.5))
                        }
                        Spacer()
                        if member.role == .admin {
                            Text("Admin")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.midnight)
                        }
                        if canRemove(member, in: club) {
                            Menu {
                                Button("Quitar del club", systemImage: "person.badge.minus", role: .destructive) {
                                    memberToRemove = member
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundStyle(Theme.ink.opacity(0.6))
                                    .frame(width: 32, height: 32)
                            }
                            .accessibilityLabel("Opciones para \(member.username)")
                        }
                    }
                    .padding(.vertical, 8)
                }
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

    // MARK: Helpers

    private func sortedMembers(_ club: Club) -> [ClubMember] {
        (club.members ?? []).sorted {
            if $0.role != $1.role { return $0.role == .admin }
            return $0.username.localizedCaseInsensitiveCompare($1.username) == .orderedAscending
        }
    }

    private func canRemove(_ member: ClubMember, in club: Club) -> Bool {
        club.isAdmin && member.id != session.user?.id
    }

    // MARK: Data

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

private struct ChannelRow: View {
    let channel: Channel

    private var isPoll: Bool { channel.type == .poll }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: isPoll ? "chart.bar.fill" : "number")
                .font(.body.weight(.semibold))
                .foregroundStyle(isPoll ? Theme.rosy : Theme.midnight)
                .frame(width: 32, height: 32)
                .background((isPoll ? Theme.rosy : Theme.midnight).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .foregroundStyle(Theme.ink)
                    .lineLimit(1)
                Text(isPoll ? "Encuesta" : "Chat")
                    .font(.caption)
                    .foregroundStyle(Theme.ink.opacity(0.55))
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Theme.ink.opacity(0.35))
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

private struct Pill: View {
    let text: String
    let systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.medium))
            .foregroundStyle(Theme.midnight)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Theme.midnight.opacity(0.1))
            .clipShape(Capsule())
    }
}
