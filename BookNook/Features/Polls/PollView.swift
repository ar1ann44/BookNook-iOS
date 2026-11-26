import SwiftUI

struct PollView: View {
    let clubId: Int
    let pollId: Int
    var isAdmin = false
    var onBookChosen: (Book) -> Void = { _ in }

    @Environment(ToastCenter.self) private var toasts
    @State private var poll: Poll?
    @State private var isChoosingBook = false
    @State private var votingOptionId: Int?
    @State private var errorMessage: String?

    private static let refreshInterval: Duration = .seconds(5)

    var body: some View {
        ScrollView {
            if let poll {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Encuesta del próximo libro", systemImage: "chart.bar.fill")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Theme.moss)
                        Text(poll.question)
                            .font(Theme.heading(26))
                            .foregroundStyle(Theme.ink)
                        Text(summary(for: poll))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    ForEach(poll.options) { option in
                        PollOptionCard(
                            option: option,
                            totalVotes: poll.totalVotes,
                            isMyVote: option.id == poll.myVoteOptionId,
                            isLeading: isLeading(option, in: poll),
                            isVoting: votingOptionId == option.id
                        ) {
                            vote(for: option)
                        }
                        .disabled(votingOptionId != nil)
                    }

                    if isAdmin, let winner = winner(of: poll) {
                        winnerCard(winner)
                    }

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(20)
            } else if let errorMessage {
                ContentUnavailableView("No se pudo cargar la encuesta", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .padding(.top, 60)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Encuesta")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await keepUpdated() }
    }

    private func summary(for poll: Poll) -> String {
        let votes = "\(poll.totalVotes) \(poll.totalVotes == 1 ? "voto" : "votos")"
        return poll.myVoteOptionId == nil
            ? "\(votes) · Toca un libro para votar"
            : "\(votes) · Toca otro libro para cambiar tu voto"
    }

    private func isLeading(_ option: PollOption, in poll: Poll) -> Bool {
        let top = poll.options.map(\.votes).max() ?? 0
        return top > 0 && option.votes == top
    }

    /// The option with the most votes, if there is a single one ahead.
    private func winner(of poll: Poll) -> PollOption? {
        let top = poll.options.map(\.votes).max() ?? 0
        let leaders = poll.options.filter { $0.votes == top }
        return top > 0 && leaders.count == 1 ? leaders.first : nil
    }

    private func winnerCard(_ option: PollOption) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Va ganando \(option.title)", systemImage: "trophy.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.ink)
            Text("Como administrador, puedes cerrar la elección y hacerlo el libro actual del club.")
                .font(.footnote)
                .foregroundStyle(Theme.ink.opacity(0.7))
            Button {
                choose(option)
            } label: {
                if isChoosingBook {
                    ProgressView().tint(.white)
                } else {
                    Text("Usar como libro actual")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(isChoosingBook)
        }
        .padding(16)
        .background(Theme.moss.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private func choose(_ option: PollOption) {
        isChoosingBook = true
        let book = Book(id: nil, title: option.title, author: option.author, coverUrl: option.coverUrl)
        Task {
            defer { isChoosingBook = false }
            do {
                _ = try await ClubService.setCurrentBook(clubId: clubId, book: book)
                onBookChosen(book)
                toasts.show("Ahora leen \(option.title)", systemImage: "book.fill")
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func keepUpdated() async {
        await load()
        while !Task.isCancelled {
            try? await Task.sleep(for: Self.refreshInterval)
            guard !Task.isCancelled, votingOptionId == nil else { continue }
            await load()
        }
    }

    private func load() async {
        do {
            poll = try await ChannelService.poll(clubId: clubId, pollId: pollId)
            errorMessage = nil
        } catch is CancellationError {
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func vote(for option: PollOption) {
        guard option.id != poll?.myVoteOptionId else { return }
        Haptics.selection()
        votingOptionId = option.id
        Task {
            defer { votingOptionId = nil }
            do {
                poll = try await ChannelService.vote(clubId: clubId, pollId: pollId, optionId: option.id)
                errorMessage = nil
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

private struct PollOptionCard: View {
    let option: PollOption
    let totalVotes: Int
    let isMyVote: Bool
    let isLeading: Bool
    let isVoting: Bool
    let onVote: () -> Void

    private var share: Double {
        totalVotes == 0 ? 0 : Double(option.votes) / Double(totalVotes)
    }

    var body: some View {
        Button(action: onVote) {
            HStack(spacing: 14) {
                BookCoverView(urlString: option.coverUrl, title: option.title, author: option.author, width: 56)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(option.title)
                            .font(Theme.body.weight(.semibold))
                            .foregroundStyle(Theme.ink)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 4)
                        if isVoting {
                            ProgressView()
                        } else if isMyVote {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Theme.midnight)
                        }
                    }
                    Text(option.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    ProgressView(value: share)
                        .tint(isLeading ? Theme.rosy : Theme.moss)
                    Text("\(option.votes) \(option.votes == 1 ? "voto" : "votos") · \(Int((share * 100).rounded()))%")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(14)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(isMyVote ? Theme.midnight : .clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(option.title) de \(option.author), \(option.votes) votos\(isMyVote ? ", tu voto" : "")")
    }
}
