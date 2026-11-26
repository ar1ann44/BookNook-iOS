import Foundation

enum APIError: LocalizedError {
    case invalidServerURL
    case unauthorized(String)
    case server(status: Int, message: String)
    case network(Error)
    case decoding(Error)

    var errorDescription: String? {
        switch self {
        case .invalidServerURL:
            return "La dirección del servidor no es válida. Revísala en la configuración del servidor."
        case .unauthorized(let message):
            return message
        case .server(_, let message):
            return message
        case .network:
            return "No se pudo conectar con el servidor de BookNook. Revisa que esté encendido y que la dirección sea correcta."
        case .decoding:
            return "El servidor envió una respuesta que la app no pudo leer."
        }
    }
}

private struct ServerErrorBody: Decodable {
    let error: String
}

enum HTTPMethod: String {
    case get = "GET", post = "POST", put = "PUT", delete = "DELETE"
}

final class APIClient {
    static let shared = APIClient()

    /// Called on the main actor when the server rejects the saved session.
    var onUnauthorized: @MainActor () -> Void = {}

    /// Requests run off the main thread, so the token is guarded by a lock
    /// instead of being read from the (main-actor) session store.
    private let tokenLock = NSLock()
    private var storedToken: String?

    var token: String? {
        get { tokenLock.withLock { storedToken } }
        set { tokenLock.withLock { storedToken = newValue } }
    }

    private let session: URLSession
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    func request<Response: Decodable>(
        _ method: HTTPMethod,
        _ path: String,
        query: [String: String] = [:],
        body: (some Encodable)? = Optional<String>.none,
        authorized: Bool = true
    ) async throws -> Response {
        var request = try makeRequest(method, path, query: query, authorized: authorized)
        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = try encoder.encode(body)
        }
        return try await perform(request, authorized: authorized)
    }

    func upload<Response: Decodable>(
        _ path: String,
        fieldName: String,
        fileName: String,
        mimeType: String,
        data: Data
    ) async throws -> Response {
        var request = try makeRequest(.post, path, query: [:], authorized: true)
        let boundary = "Boundary-\(UUID().uuidString)"
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"\(fieldName)\"; filename=\"\(fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(data)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)
        request.httpBody = body

        return try await perform(request, authorized: true)
    }

    private func makeRequest(
        _ method: HTTPMethod,
        _ path: String,
        query: [String: String],
        authorized: Bool
    ) throws -> URLRequest {
        guard let base = ServerConfig.baseURL,
              var components = URLComponents(url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
        else { throw APIError.invalidServerURL }

        if !query.isEmpty {
            components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        }
        guard let url = components.url else { throw APIError.invalidServerURL }

        var request = URLRequest(url: url, timeoutInterval: 15)
        request.httpMethod = method.rawValue
        if authorized, let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    private func perform<Response: Decodable>(_ request: URLRequest, authorized: Bool) async throws -> Response {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw APIError.network(error)
        }

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let message = (try? decoder.decode(ServerErrorBody.self, from: data))?.error
                ?? "Algo salió mal (error \(status))."
            if status == 401 {
                if authorized { await MainActor.run { onUnauthorized() } }
                throw APIError.unauthorized(message)
            }
            throw APIError.server(status: status, message: message)
        }

        do {
            return try decoder.decode(Response.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
