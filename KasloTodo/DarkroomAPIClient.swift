import Foundation

// MARK: - DarkroomAPIClient
// Talks to /darkroom-device-api.php using the same kw_ Bearer key as the todo API.
// All JSON uses snake_case on the wire; encoder/decoder convert automatically.

enum DarkroomAPIClient {

    // MARK: - Codec

    static func makeDecoder() -> JSONDecoder {
        let d = JSONDecoder()
        d.keyDecodingStrategy = .convertFromSnakeCase
        return d
    }

    static func makeEncoder() -> JSONEncoder {
        let e = JSONEncoder()
        e.keyEncodingStrategy = .convertToSnakeCase
        return e
    }

    // MARK: - Wire envelope
    private struct Envelope<T: Decodable>: Decodable {
        var ok: Bool
        var data: T?
        var error: String?
    }

    private struct CreatedData: Decodable { var id: Int }
    private struct MutatedData: Decodable { var updated: Int?; var deleted: Int? }

    // MARK: - CRUD

    static func list<T: Decodable>(
        _ type: T.Type, serverURL: String, apiKey: String, res: String
    ) async throws -> T {
        let url  = try buildURL(serverURL, res: res, id: nil, apiKey: apiKey)
        let raw  = try await perform(url: url, method: "GET", body: nil, apiKey: apiKey)
        let env  = try makeDecoder().decode(Envelope<T>.self, from: raw)
        guard env.ok, let data = env.data else {
            throw APIError.httpError(0, env.error ?? "Unknown error")
        }
        return data
    }

    static func create<B: Encodable>(
        serverURL: String, apiKey: String, res: String, body: B
    ) async throws -> Int {
        let url     = try buildURL(serverURL, res: res, id: nil, apiKey: apiKey)
        let bodyData = try makeEncoder().encode(body)
        let raw     = try await perform(url: url, method: "POST", body: bodyData, apiKey: apiKey)
        let env     = try makeDecoder().decode(Envelope<CreatedData>.self, from: raw)
        guard env.ok, let data = env.data else {
            throw APIError.httpError(0, env.error ?? "Create failed")
        }
        return data.id
    }

    static func update<B: Encodable>(
        serverURL: String, apiKey: String, res: String, id: Int, body: B
    ) async throws {
        let url     = try buildURL(serverURL, res: res, id: id, apiKey: apiKey)
        let bodyData = try makeEncoder().encode(body)
        let raw     = try await perform(url: url, method: "PATCH", body: bodyData, apiKey: apiKey)
        let env     = try makeDecoder().decode(Envelope<MutatedData>.self, from: raw)
        guard env.ok else { throw APIError.httpError(0, env.error ?? "Update failed") }
    }

    static func delete(
        serverURL: String, apiKey: String, res: String, id: Int
    ) async throws {
        let url = try buildURL(serverURL, res: res, id: id, apiKey: apiKey)
        let raw = try await perform(url: url, method: "DELETE", body: nil, apiKey: apiKey)
        let env = try makeDecoder().decode(Envelope<MutatedData>.self, from: raw)
        guard env.ok else { throw APIError.httpError(0, env.error ?? "Delete failed") }
    }

    // MARK: - Internals

    private static func buildURL(
        _ base: String, res: String, id: Int?, apiKey: String
    ) throws -> URL {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard var comps = URLComponents(string: trimmed + "/darkroom-device-api.php") else {
            throw APIError.badURL
        }
        var items = [
            URLQueryItem(name: "res",     value: res),
            URLQueryItem(name: "api_key", value: apiKey),
        ]
        if let id { items.insert(URLQueryItem(name: "id", value: String(id)), at: 1) }
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.badURL }
        return url
    }

    private static func perform(
        url: URL, method: String, body: Data?, apiKey: String
    ) async throws -> Data {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let e as URLError {
            switch e.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.networkError("No internet connection")
            case .timedOut:
                throw APIError.networkError("Request timed out")
            case .cannotFindHost, .cannotConnectToHost:
                throw APIError.networkError("Cannot reach server")
            default:
                throw APIError.networkError(e.localizedDescription)
            }
        }

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.networkError("No HTTP response")
        }
        if http.statusCode == 401 { throw APIError.unauthorized }
        return data
    }
}
