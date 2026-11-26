import Foundation

enum ClubService {
    private static var api: APIClient { .shared }

    private struct Empty: Decodable {}

    static func myClubs() async throws -> [Club] {
        try await api.request(.get, "clubs/mine")
    }

    static func publicClubs() async throws -> [Club] {
        try await api.request(.get, "clubs/public")
    }

    static func club(id: Int) async throws -> Club {
        try await api.request(.get, "clubs/\(id)")
    }

    static func create(_ club: NewClub) async throws -> Club {
        try await api.request(.post, "clubs", body: club)
    }

    static func join(clubId: Int) async throws {
        let _: Empty = try await api.request(.post, "clubs/\(clubId)/join")
    }

    static func join(code: String) async throws -> JoinByCodeResponse {
        struct Body: Encodable { let code: String }
        return try await api.request(.post, "clubs/join-by-code", body: Body(code: code))
    }

    /// Saves the club's editable fields. `currentBook` is always sent, so
    /// passing nil clears it.
    static func update(clubId: Int, name: String, description: String, currentBook: Book?) async throws -> Club {
        struct Body: Encodable {
            let name: String
            let description: String
            let currentBook: Book?

            func encode(to encoder: Encoder) throws {
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode(name, forKey: .name)
                try container.encode(description, forKey: .description)
                try container.encode(currentBook, forKey: .currentBook)
            }

            enum CodingKeys: String, CodingKey { case name, description, currentBook }
        }
        return try await api.request(
            .put, "clubs/\(clubId)",
            body: Body(name: name, description: description, currentBook: currentBook)
        )
    }

    static func setCurrentBook(clubId: Int, book: Book) async throws -> Club {
        struct Body: Encodable { let currentBook: Book }
        return try await api.request(.put, "clubs/\(clubId)", body: Body(currentBook: book))
    }

    static func leave(clubId: Int) async throws {
        let _: Empty = try await api.request(.post, "clubs/\(clubId)/leave")
    }

    static func removeMember(clubId: Int, userId: Int) async throws {
        let _: Empty = try await api.request(.delete, "clubs/\(clubId)/members/\(userId)")
    }
}
