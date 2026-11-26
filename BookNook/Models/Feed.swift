import Foundation

struct ClubActivity: Codable, Identifiable, Hashable {
    struct LatestMessage: Codable, Hashable {
        let id: Int
        let content: String
        let createdAt: String
        let username: String
        var avatarUrl: String?
        let channelId: Int
        let channelName: String
    }

    let clubId: Int
    let clubName: String
    let unreadCount: Int
    let latestMessage: LatestMessage

    var id: Int { clubId }

    var channel: Channel {
        Channel(id: latestMessage.channelId, clubId: clubId, name: latestMessage.channelName, type: .general)
    }
}

struct RecommendationSection: Codable, Identifiable, Hashable {
    let genre: String
    let books: [Book]

    var id: String { genre }
}

struct Recommendations: Codable {
    let basedOnProfile: Bool
    let sections: [RecommendationSection]
}
