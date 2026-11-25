import Foundation

enum ServerConfig {
    private static let key = "serverURL"
    static let defaultURL = "http://localhost:4000"

    static var baseURLString: String {
        get { UserDefaults.standard.string(forKey: key) ?? defaultURL }
        set {
            let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleaned = trimmed.hasSuffix("/") ? String(trimmed.dropLast()) : trimmed
            UserDefaults.standard.set(cleaned.isEmpty ? defaultURL : cleaned, forKey: key)
        }
    }

    static var baseURL: URL? { URL(string: baseURLString) }

    /// Turns a server path such as "/uploads/1.jpg" into a full URL.
    static func resolve(_ pathOrURL: String?) -> URL? {
        guard let value = pathOrURL, !value.isEmpty else { return nil }
        if value.hasPrefix("http") { return URL(string: value) }
        return URL(string: baseURLString + (value.hasPrefix("/") ? value : "/" + value))
    }
}
