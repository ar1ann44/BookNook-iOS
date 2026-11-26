import Foundation

enum FeedService {
    static func clubActivity() async throws -> [ClubActivity] {
        try await APIClient.shared.request(.get, "me/club-activity")
    }

    static func recommendations() async throws -> Recommendations {
        try await APIClient.shared.request(.get, "api/books/recommendations")
    }
}
