import Foundation
import Observation
import UIKit

@MainActor
@Observable
final class ProfileStore {
    private(set) var profile: Profile?
    private(set) var isLoading = false
    var errorMessage: String?

    private let api: APIClient

    init(api: APIClient = .shared) {
        self.api = api
    }

    func load() async {
        isLoading = profile == nil
        defer { isLoading = false }
        do {
            profile = try await api.request(.get, "profile")
            errorMessage = nil
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func save(bio: String, genres: [String], topBooks: [Book]) async throws {
        let update = ProfileUpdate(
            bio: bio.trimmingCharacters(in: .whitespacesAndNewlines),
            genres: genres,
            topBooks: Array(topBooks.prefix(Profile.maxTopBooks))
        )
        profile = try await api.request(.put, "profile", body: update)
    }

    func uploadAvatar(_ image: UIImage) async throws {
        guard let data = image.resizedForUpload(maxSide: 800).jpegData(compressionQuality: 0.8) else { return }
        let response: AvatarResponse = try await api.upload(
            "profile/avatar",
            fieldName: "avatar",
            fileName: "avatar.jpg",
            mimeType: "image/jpeg",
            data: data
        )
        profile?.avatarUrl = response.avatarUrl
    }
}

private extension UIImage {
    func resizedForUpload(maxSide: CGFloat) -> UIImage {
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return self }
        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
