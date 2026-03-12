import Foundation

enum APIError: LocalizedError {
    case badURL
    case httpError(Int, String?)
    case decodeFailed(String)
    case unauthorized
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .badURL:                    return "Invalid server URL"
        case .httpError(let c, let m):   return "Server error \(c)\(m.map { ": \($0)" } ?? "")"
        case .decodeFailed(let m):       return "Bad response: \(m)"
        case .unauthorized:              return "API key rejected — check Settings"
        case .networkError(let m):       return "Network error: \(m)"
        }
    }
}

// MARK: - APIClient

/// All calls go to /device-api.php using Bearer token auth.
/// The server is the source of truth for id, created, and initial done=false.
enum APIClient {

    // MARK: Todos

    /// GET /device-api.php  — fetch full list
    static func fetchTodos(serverURL: String, apiKey: String) async throws -> [TodoItem] {
        let url = try buildURL(serverURL, path: "/device-api.php", query: nil, apiKey: apiKey)
        let (data, _) = try await perform(url: url, method: "GET", body: nil, apiKey: apiKey)
        do {
            return try JSONDecoder().decode([TodoItem].self, from: data)
        } catch {
            throw APIError.decodeFailed(error.localizedDescription)
        }
    }

    /// GET /device-api.php?id=X  — fetch one item
    static func fetchTodo(serverURL: String, apiKey: String, id: String) async throws -> TodoItem {
        let url = try buildURL(serverURL, path: "/device-api.php", query: ["id": id], apiKey: apiKey)
        let (data, _) = try await perform(url: url, method: "GET", body: nil, apiKey: apiKey)
        do {
            return try JSONDecoder().decode(TodoItem.self, from: data)
        } catch {
            throw APIError.decodeFailed(error.localizedDescription)
        }
    }

    /// POST /device-api.php  — add ONE new item (server assigns id/created/done)
    /// Sends only mutable fields; server ignores id/created/done in the body.
    static func addTodo(serverURL: String, apiKey: String, draft: TodoDraft) async throws -> TodoItem {
        let url  = try buildURL(serverURL, path: "/device-api.php", query: nil, apiKey: apiKey)
        let body = try JSONEncoder().encode(draft)
        let (data, _) = try await perform(url: url, method: "POST", body: body, apiKey: apiKey)
        do {
            return try JSONDecoder().decode(TodoItem.self, from: data)
        } catch {
            throw APIError.decodeFailed(error.localizedDescription)
        }
    }

    /// PATCH /device-api.php?id=X  — update mutable fields only
    static func patchTodo(serverURL: String, apiKey: String, id: String, patch: [String: AnyEncodable]) async throws -> TodoItem {
        let url  = try buildURL(serverURL, path: "/device-api.php", query: ["id": id], apiKey: apiKey)
        let body = try JSONEncoder().encode(patch)
        let (data, _) = try await perform(url: url, method: "PATCH", body: body, apiKey: apiKey)
        do {
            return try JSONDecoder().decode(TodoItem.self, from: data)
        } catch {
            throw APIError.decodeFailed(error.localizedDescription)
        }
    }

    /// DELETE /device-api.php?id=X  — permanently remove an item
    static func deleteTodo(serverURL: String, apiKey: String, id: String) async throws {
        let url = try buildURL(serverURL, path: "/device-api.php", query: ["id": id], apiKey: apiKey)
        _ = try await perform(url: url, method: "DELETE", body: nil, apiKey: apiKey)
    }

    // MARK: Internals

    private static func buildURL(_ base: String, path: String, query: [String: String]?, apiKey: String) throws -> URL {
        let trimmed = base.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard var comps = URLComponents(string: trimmed + path) else { throw APIError.badURL }
        // Always send key as query param — Apache+PHP-FPM strips the Authorization
        // header unless .htaccess RewriteRule passthrough is configured, so the
        // query-string path is the reliable fallback that always reaches PHP.
        var items = query.map { $0.map { URLQueryItem(name: $0.key, value: $0.value) } } ?? []
        items.append(URLQueryItem(name: "api_key", value: apiKey))
        comps.queryItems = items
        guard let url = comps.url else { throw APIError.badURL }
        return url
    }

    private static func perform(url: URL, method: String, body: Data?, apiKey: String) async throws -> (Data, HTTPURLResponse) {
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        // Authorization header: works on mod_php and PHP-FPM with .htaccess passthrough
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            req.httpBody = body
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch let error as URLError {
            // Provide helpful error messages for common network issues
            switch error.code {
            case .notConnectedToInternet, .networkConnectionLost:
                throw APIError.networkError("No internet connection")
            case .timedOut:
                throw APIError.networkError("Request timed out. Check your server URL and network connection.")
            case .cannotFindHost, .cannotConnectToHost:
                throw APIError.networkError("Cannot reach server. Check your server URL.")
            case .secureConnectionFailed:
                throw APIError.networkError("Secure connection failed. Ensure your server uses HTTPS.")
            case .appTransportSecurityRequiresSecureConnection:
                throw APIError.networkError("HTTP not allowed. Use HTTPS or configure App Transport Security.")
            default:
                throw APIError.networkError(error.localizedDescription)
            }
        } catch {
            throw APIError.networkError(error.localizedDescription)
        }

        guard let http = resp as? HTTPURLResponse else {
            throw APIError.networkError("No HTTP response")
        }
        
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode >= 400 {
            let msg = (try? JSONDecoder().decode([String: String].self, from: data))?["error"]
            throw APIError.httpError(http.statusCode, msg)
        }
        return (data, http)
    }
}

// MARK: - TodoDraft  (what the app sends to the server on POST)

/// Mutable fields only — server assigns id, created, done.
struct TodoDraft: Encodable {
    var text:         String
    var priority:     Int
    var due:          String?
    var notes:        String?
    var tags:         [String]
    var recurWeekday: String?
    var recurDay:     String?

    init(from item: TodoItem) {
        text         = item.text
        priority     = item.priority
        due          = item.due
        notes        = item.notes
        tags         = item.tags
        recurWeekday = item.recurWeekday
        recurDay     = item.recurDay
    }

    init(text: String, priority: Int = 3, due: String? = nil,
         notes: String? = nil, tags: [String] = []) {
        self.text     = text
        self.priority = priority
        self.due      = due
        self.notes    = notes
        self.tags     = tags
        recurWeekday  = nil
        recurDay      = nil
    }
}

// MARK: - AnyEncodable  (for PATCH dictionaries)

struct AnyEncodable: Encodable {
    let value: Any?

    init(_ value: Any?) { self.value = value }

    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        switch value {
        case nil:                           try c.encodeNil()
        case let v as Bool:                 try c.encode(v)
        case let v as Int:                  try c.encode(v)
        case let v as String:               try c.encode(v)
        case let v as [String]:             try c.encode(v)
        case let v as [String: AnyEncodable]: try c.encode(v)
        default:                            try c.encodeNil()
        }
    }
}
