import Foundation

enum BookService {
    static func search(_ query: String, limit: Int = 15) async throws -> [Book] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return try await APIClient.shared.request(
            .get, "api/books/search",
            query: ["q": trimmed, "limit": String(limit)]
        )
    }
}
