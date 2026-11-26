import SwiftUI

struct ChannelChatView: View {
    let clubId: Int
    let channel: Channel

    @Environment(SessionStore.self) private var session
    @State private var messages: [ChatMessage] = []
    @State private var draft = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var errorMessage: String?
    @FocusState private var inputFocused: Bool

    private static let refreshInterval: Duration = .seconds(3)
    private let bottomID = "bottom"

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 6) {
                    if !isLoading && messages.isEmpty {
                        ContentUnavailableView(
                            "Aún no hay mensajes",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("¡Saluda al club!")
                        )
                        .padding(.top, 60)
                    }
                    ForEach(Array(messages.enumerated()), id: \.element.id) { index, message in
                        MessageBubble(
                            message: message,
                            isMine: message.userId == session.user?.id,
                            showsAuthor: index == 0 || messages[index - 1].userId != message.userId
                        )
                    }
                    Color.clear.frame(height: 1).id(bottomID)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background.ignoresSafeArea())
            .overlay { if isLoading { ProgressView() } }
            .safeAreaInset(edge: .bottom) { inputBar }
            .onChange(of: messages.last?.id) { _, _ in
                withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) }
            }
            .onChange(of: inputFocused) { _, focused in
                if focused { withAnimation { proxy.scrollTo(bottomID, anchor: .bottom) } }
            }
        }
        .navigationTitle("# \(channel.name)")
        .navigationBarTitleDisplayMode(.inline)
        .task { await keepUpdated() }
    }

    private var inputBar: some View {
        VStack(spacing: 4) {
            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            HStack(alignment: .bottom, spacing: 8) {
                TextField("Mensaje en #\(channel.name)", text: $draft, axis: .vertical)
                    .lineLimit(1...5)
                    .focused($inputFocused)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .overlay(RoundedRectangle(cornerRadius: 20).stroke(Theme.locked))

                Button(action: send) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 34))
                        .foregroundStyle(canSend ? Theme.rosy : Theme.locked)
                }
                .disabled(!canSend)
                .accessibilityLabel("Enviar")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isSending
    }

    private func keepUpdated() async {
        await fetch()
        isLoading = false
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.refreshInterval)
            guard !Task.isCancelled else { return }
            await fetch()
        }
    }

    private func fetch() async {
        do {
            let newer = try await ChannelService.messages(
                clubId: clubId, channelId: channel.id, after: messages.last?.id
            )
            append(newer)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            if messages.isEmpty { errorMessage = error.localizedDescription }
        }
    }

    private func append(_ newer: [ChatMessage]) {
        let known = Set(messages.map(\.id))
        let fresh = newer.filter { !known.contains($0.id) }
        guard !fresh.isEmpty else { return }
        messages.append(contentsOf: fresh)
        messages.sort { $0.id < $1.id }
    }

    private func send() {
        let content = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }
        isSending = true
        draft = ""
        Task {
            defer { isSending = false }
            do {
                let message = try await ChannelService.send(content, clubId: clubId, channelId: channel.id)
                append([message])
                errorMessage = nil
            } catch {
                draft = content
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct MessageBubble: View {
    let message: ChatMessage
    let isMine: Bool
    let showsAuthor: Bool

    var body: some View {
        VStack(alignment: isMine ? .trailing : .leading, spacing: 2) {
            if showsAuthor {
                HStack(spacing: 6) {
                    if !isMine {
                        Text(message.username)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.midnight)
                    }
                    Text(ServerDate.shortLabel(message.createdAt))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 8)
                .padding(.horizontal, 4)
            }
            Text(message.content)
                .font(Theme.body)
                .foregroundStyle(isMine ? .white : Theme.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(isMine ? Theme.midnight : Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: isMine ? .trailing : .leading)
        .padding(isMine ? .leading : .trailing, 48)
    }
}
