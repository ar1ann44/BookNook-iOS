import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    private(set) var user: User?
    private(set) var isRestoring = true

    private var token: String?
    private let api: APIClient

    private enum Keys {
        static let token = "authToken"
        static let user = "authUser"
    }

    var isSignedIn: Bool { user != nil && token != nil }

    init(api: APIClient = .shared) {
        self.api = api
        api.tokenProvider = { [weak self] in
            MainActor.assumeIsolated { self?.token }
        }
        api.onUnauthorized = { [weak self] in
            self?.signOut()
        }
    }

    func restore() async {
        defer { isRestoring = false }
        guard
            let tokenData = KeychainStore.load(Keys.token),
            let savedToken = String(data: tokenData, encoding: .utf8),
            let userData = KeychainStore.load(Keys.user),
            let savedUser = try? JSONDecoder().decode(User.self, from: userData)
        else { return }

        token = savedToken
        user = savedUser
    }

    func logIn(email: String, password: String) async throws {
        struct Body: Encodable { let email: String; let password: String }
        let response: AuthResponse = try await api.request(
            .post, "login",
            body: Body(email: email, password: password),
            authorized: false
        )
        store(response)
    }

    func signUp(username: String, email: String, password: String) async throws {
        struct Body: Encodable { let username: String; let email: String; let password: String }
        let response: AuthResponse = try await api.request(
            .post, "signup",
            body: Body(username: username, email: email, password: password),
            authorized: false
        )
        store(response)
    }

    func signOut() {
        token = nil
        user = nil
        KeychainStore.delete(Keys.token)
        KeychainStore.delete(Keys.user)
    }

    private func store(_ response: AuthResponse) {
        token = response.token
        user = response.user
        KeychainStore.save(Data(response.token.utf8), for: Keys.token)
        if let userData = try? JSONEncoder().encode(response.user) {
            KeychainStore.save(userData, for: Keys.user)
        }
    }
}
