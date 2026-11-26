import Foundation

enum FeedService {
    static func activity(limit: Int = 5) async throws -> [ActivityItem] {
        try await APIClient.shared.request(.get, "me/activity", query: ["limit": String(limit)])
    }

    static func recommendations() async throws -> Recommendations {
        try await APIClient.shared.request(.get, "api/books/recommendations")
    }
}
