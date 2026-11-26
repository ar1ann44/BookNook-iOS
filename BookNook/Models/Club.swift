import Foundation

enum ClubPrivacy: String, Codable, CaseIterable, Identifiable {
    case `public`
    case `private`

    var id: String { rawValue }
    var label: String { self == .public ? "Público" : "Privado" }
    var systemImage: String { self == .public ? "globe" : "lock.fill" }
}

enum ClubRole: String, Codable {
    case admin
    case member
}

struct ClubMember: Codable, Identifiable, Hashable {
    let id: Int
    let username: String
    let role: ClubRole
}

struct Club: Codable, Identifiable, Hashable {
    let id: Int
    var name: String
    var description: String
    var privacy: ClubPrivacy
    var ownerId: Int
    var currentBook: Book?
    var createdAt: String?
    var role: ClubRole?
    var memberCount: Int?
    var isMember: Bool?
    var members: [ClubMember]?
    var inviteCode: String?

    var isAdmin: Bool { role == .admin }
}

struct NewClub: Encodable {
    let name: String
    let description: String
    let privacy: ClubPrivacy
    let currentBook: Book?
}

struct JoinByCodeResponse: Decodable {
    let id: Int
    let message: String?
}
