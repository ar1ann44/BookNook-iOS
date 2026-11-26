import SwiftUI

struct PollView: View {
    let clubId: Int
    let pollId: Int

    @State private var poll: Poll?
    @State private var votingOptionId: Int?
    @State private var errorMessage: String?

    private static let refreshInterval: Duration = .seconds(5)

    var body: some View {
        ScrollView {
            if let poll {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Next book poll", systemImage: "chart.bar.fill")
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

                    if let errorMessage {
                        Text(errorMessage).font(.footnote).foregroundStyle(.red)
                    }
                }
                .padding(20)
            } else if let errorMessage {
                ContentUnavailableView("Could not load the poll", systemImage: "exclamationmark.triangle", description: Text(errorMessage))
                    .padding(.top, 60)
            } else {
                ProgressView().padding(.top, 80)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Poll")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await load() }
        .task { await keepUpdated() }
    }

    private func summary(for poll: Poll) -> String {
        let votes = "\(poll.totalVotes) \(poll.totalVotes == 1 ? "vote" : "votes")"
        return poll.myVoteOptionId == nil
            ? "\(votes) · Tap a book to vote"
            : "\(votes) · Tap another book to change your vote"
    }

    private func isLeading(_ option: PollOption, in poll: Poll) -> Bool {
        let top = poll.options.map(\.votes).max() ?? 0
        return top > 0 && option.votes == top
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
                BookCoverView(urlString: option.coverUrl, width: 56)
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
                    Text("\(option.votes) \(option.votes == 1 ? "vote" : "votes") · \(Int((share * 100).rounded()))%")
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
        .accessibilityLabel("\(option.title) by \(option.author), \(option.votes) votes\(isMyVote ? ", your vote" : "")")
    }
}
