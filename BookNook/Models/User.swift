import Foundation

struct User: Codable, Identifiable, Equatable {
    let id: Int
    let username: String
    let email: String
}

struct AuthResponse: Decodable {
    let user: User
    let token: String
}
