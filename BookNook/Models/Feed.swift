import Foundation

struct ActivityItem: Codable, Identifiable, Hashable {
    let id: Int
    let content: String
    let createdAt: String
    let username: String
    let clubId: Int
    let clubName: String
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
