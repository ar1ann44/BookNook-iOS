import Foundation

enum ChannelType: String, Codable {
    case general
    case poll
}

struct Channel: Codable, Identifiable, Hashable {
    let id: Int
    let clubId: Int
    var name: String
    var type: ChannelType
    var createdAt: String?
    var pollId: Int?
    var unreadCount: Int?
}

struct ChatMessage: Codable, Identifiable, Hashable {
    let id: Int
    let content: String
    let createdAt: String
    let userId: Int
    let username: String
    var avatarUrl: String?
}

struct PollOption: Codable, Identifiable, Hashable {
    let id: Int
    let title: String
    let author: String
    let coverUrl: String?
    let votes: Int
}

struct Poll: Codable, Identifiable, Hashable {
    let id: Int
    let channelId: Int
    let question: String
    let createdAt: String?
    let myVoteOptionId: Int?
    let options: [PollOption]

    var totalVotes: Int { options.reduce(0) { $0 + $1.votes } }
}

struct CreatePollResponse: Decodable {
    let channel: Channel
    let poll: Poll
}
