import Foundation

enum ChannelService {
    private static var api: APIClient { .shared }

    static func channels(clubId: Int) async throws -> [Channel] {
        try await api.request(.get, "clubs/\(clubId)/channels")
    }

    static func createChannel(clubId: Int, name: String) async throws -> Channel {
        struct Body: Encodable { let name: String }
        return try await api.request(.post, "clubs/\(clubId)/channels", body: Body(name: name))
    }

    static func messages(clubId: Int, channelId: Int, after lastId: Int? = nil) async throws -> [ChatMessage] {
        var query: [String: String] = [:]
        if let lastId { query["after"] = String(lastId) }
        return try await api.request(.get, "clubs/\(clubId)/channels/\(channelId)/messages", query: query)
    }

    static func send(_ content: String, clubId: Int, channelId: Int) async throws -> ChatMessage {
        struct Body: Encodable { let content: String }
        return try await api.request(
            .post, "clubs/\(clubId)/channels/\(channelId)/messages",
            body: Body(content: content)
        )
    }

    @discardableResult
    static func markRead(clubId: Int, channelId: Int, messageId: Int) async throws -> Int {
        struct Body: Encodable { let messageId: Int }
        struct Response: Decodable { let unreadCount: Int }
        let response: Response = try await api.request(
            .post, "clubs/\(clubId)/channels/\(channelId)/read",
            body: Body(messageId: messageId)
        )
        return response.unreadCount
    }

    static func poll(clubId: Int, pollId: Int) async throws -> Poll {
        try await api.request(.get, "clubs/\(clubId)/polls/\(pollId)")
    }

    static func vote(clubId: Int, pollId: Int, optionId: Int) async throws -> Poll {
        struct Body: Encodable { let optionId: Int }
        return try await api.request(.post, "clubs/\(clubId)/polls/\(pollId)/vote", body: Body(optionId: optionId))
    }

    static func createPoll(clubId: Int, question: String, books: [Book]) async throws -> CreatePollResponse {
        struct Option: Encodable { let title: String; let author: String; let coverUrl: String? }
        struct Body: Encodable { let question: String; let options: [Option] }
        let body = Body(
            question: question,
            options: books.map { Option(title: $0.title, author: $0.author, coverUrl: $0.coverUrl) }
        )
        return try await api.request(.post, "clubs/\(clubId)/polls", body: body)
    }
}
