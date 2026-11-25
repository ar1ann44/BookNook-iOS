import Foundation

struct Book: Codable, Identifiable, Hashable {
    var id: String?
    var title: String
    var author: String
    var coverUrl: String?
    var description: String?
    var categories: [String]?
    var publishedDate: String?

    var stableID: String { id ?? "\(title)|\(author)" }
}
