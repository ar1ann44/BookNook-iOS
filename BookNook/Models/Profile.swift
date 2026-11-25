import Foundation

struct Profile: Codable, Equatable {
    var username: String
    var email: String
    var bio: String
    var avatarUrl: String?
    var genres: [String]
    var topBooks: [Book]

    static let maxTopBooks = 4
}

struct ProfileUpdate: Encodable {
    let bio: String
    let genres: [String]
    let topBooks: [Book]
}

struct AvatarResponse: Decodable {
    let avatarUrl: String
}
