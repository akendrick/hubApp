import Foundation

enum DarkroomAPIClient {
    private static let requestTimeout: TimeInterval = 60
    private static let retryableAttempts = 2

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder(); d.keyDecodingStrategy = .convertFromSnakeCase; return d
    }
    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder(); e.keyEncodingStrategy = .convertToSnakeCase; return e
    }

    private struct Envelope<T: Decodable>: Decodable { var ok: Bool; var data: T?; var error: String? }
    private struct CreatedData: Decodable { var id: Int }
    private struct MutatedData: Decodable { var updated: Int?; var deleted: Int? }

    // MARK: - CRUD

    static func list<T: Decodable>(_ type: T.Type, serverURL: String, apiKey: String, res: String) async throws -> T {
        let url  = try buildURL(serverURL, res: res, id: nil, apiKey: apiKey)
        let raw  = try await perform(url: url, method: "GET", body: nil, apiKey: apiKey)
        let env  = try makeDecoder().decode(Envelope<T>.self, from: raw)
        guard env.ok, let data = env.data else { throw APIError.httpError(0, env.error ?? "Unknown") }
        return data
    }

    static func create<B: Encodable>(serverURL: String, apiKey: String, res: String, body: B) async throws -> Int {
        let url     = try buildURL(serverURL, res: res, id: nil, apiKey: apiKey)
        let bodyData = try makeEncoder().encode(body)
        let raw     = try await perform(url: url, method: "POST", body: bodyData, apiKey: apiKey)
        let env     = try makeDecoder().decode(Envelope<CreatedData>.self, from: raw)
        guard env.ok, let data = env.data else { throw APIError.httpError(0, env.error ?? "Create failed") }
        return data.id
    }

    static func update<B: Encodable>(serverURL: String, apiKey: String, res: String, id: Int, body: B) async throws {
        let url      = try buildURL(serverURL, res: res, id: id, apiKey: apiKey)
        let bodyData = try makeEncoder().encode(body)
        let raw      = try await perform(url: url, method: "PATCH", body: bodyData, apiKey: apiKey)
        let env      = try makeDecoder().decode(Envelope<MutatedData>.self, from: raw)
        guard env.ok else { throw APIError.httpError(0, env.error ?? "Update failed") }
    }

    static func delete(serverURL: String, apiKey: String, res: String, id: Int) async throws {
        let url = try buildURL(serverURL, res: res, id: id, apiKey: apiKey)
        let raw = try await perform(url: url, method: "DELETE", body: nil, apiKey: apiKey)
        let env = try makeDecoder().decode(Envelope<MutatedData>.self, from: raw)
        guard env.ok else { throw APIError.httpError(0, env.error ?? "Delete failed") }
    }

    // MARK: - Image upload

    static func uploadImage(serverURL: String, apiKey: String, photoId: Int, imageData: Data, mimeType: String) async throws -> String {
        let trimmed = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard var comps = URLComponents(string: trimmed + "/darkroom-device-api.php") else { throw APIError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "res",     value: "photo_image"),
            URLQueryItem(name: "id",      value: String(photoId)),
            URLQueryItem(name: "api_key", value: apiKey),
        ]
        guard let url = comps.url else { throw APIError.badURL }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(mimeType)\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url, timeoutInterval: requestTimeout)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, _) = try await data(for: req)

        struct ImageResult: Decodable { var imagePath: String }
        let env = try makeDecoder().decode(Envelope<ImageResult>.self, from: data)
        guard env.ok, let result = env.data else { throw APIError.httpError(0, env.error ?? "Upload failed") }
        return result.imagePath
    }

    // MARK: - Internals

    static func buildURL(_ base: String, res: String, id: Int?, apiKey: String) throws -> URL {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard var comps = URLComponents(string: trimmed + "/darkroom-device-api.php") else { throw APIError.badURL }
        var items = [URLQueryItem(name: "res", value: res), URLQueryItem(name: "api_key", value: apiKey)]
        if let id { items.insert(URLQueryItem(name: "id", value: String(id)), at: 1) }
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.badURL }
        return url
    }

    static func perform(url: URL, method: String, body: Data?, apiKey: String) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: requestTimeout)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, resp) = try await data(for: req)
        guard let http = resp as? HTTPURLResponse else { throw APIError.networkError("No HTTP response") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        return data
    }

    private static func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: URLError?

        for attempt in 1...retryableAttempts {
            do {
                return try await URLSession.shared.data(for: request)
            } catch is CancellationError {
                throw CancellationError()
            } catch let error as URLError {
                if error.code == .cancelled { throw CancellationError() }
                lastError = error

                if error.code == .timedOut && attempt < retryableAttempts {
                    try? await Task.sleep(for: .seconds(Double(attempt)))
                    continue
                }
                throw map(error)
            } catch {
                throw APIError.networkError(error.localizedDescription)
            }
        }

        if let lastError {
            throw map(lastError)
        }
        throw APIError.networkError("Request failed")
    }

    private static func map(_ error: URLError) -> APIError {
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost:
            return .networkError("No internet")
        case .timedOut:
            return .networkError("Request timed out")
        case .cannotFindHost, .cannotConnectToHost:
            return .networkError("Cannot reach server")
        default:
            return .networkError(error.localizedDescription)
        }
    }
}
