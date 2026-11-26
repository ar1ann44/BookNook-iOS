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

    static func removeMember(clubId: Int, userId: Int) async throws {
        let _: Empty = try await api.request(.delete, "clubs/\(clubId)/members/\(userId)")
    }
}
