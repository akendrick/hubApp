import Foundation
import UIKit

extension Error {
    var isRequestCancellation: Bool {
        if self is CancellationError {
            return true
        }

        if let urlError = self as? URLError {
            return urlError.code == .cancelled
        }

        let nsError = self as NSError
        return nsError.domain == NSURLErrorDomain && nsError.code == URLError.cancelled.rawValue
    }
}

enum DarkroomAPIClient {

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
        let url = try buildURL(serverURL, res: res, id: nil, apiKey: apiKey)
        let raw = try await perform(url: url, method: "GET", body: nil, apiKey: apiKey)
        return try decodeEnvelope(T.self, from: raw, context: res)
    }

    static func create<B: Encodable>(serverURL: String, apiKey: String, res: String, body: B) async throws -> Int {
        let url      = try buildURL(serverURL, res: res, id: nil, apiKey: apiKey)
        let bodyData = try makeEncoder().encode(body)
        let raw      = try await perform(url: url, method: "POST", body: bodyData, apiKey: apiKey)
        let env      = try decodeEnvelopeRaw(CreatedData.self, from: raw, context: res)
        return env.id
    }

    static func update<B: Encodable>(serverURL: String, apiKey: String, res: String, id: Int, body: B) async throws {
        let url      = try buildURL(serverURL, res: res, id: id, apiKey: apiKey)
        let bodyData = try makeEncoder().encode(body)
        let raw      = try await perform(url: url, method: "PATCH", body: bodyData, apiKey: apiKey)
        _ = try decodeEnvelopeRaw(MutatedData.self, from: raw, context: res)
    }

    static func delete(serverURL: String, apiKey: String, res: String, id: Int) async throws {
        let url = try buildURL(serverURL, res: res, id: id, apiKey: apiKey)
        let raw = try await perform(url: url, method: "DELETE", body: nil, apiKey: apiKey)
        _ = try decodeEnvelopeRaw(MutatedData.self, from: raw, context: res)
    }

    // Decode an envelope and return the inner data, throwing a readable error on failure
    private static func decodeEnvelope<T: Decodable>(_ type: T.Type, from raw: Data, context: String) throws -> T {
        let env: Envelope<T>
        do {
            env = try makeDecoder().decode(Envelope<T>.self, from: raw)
        } catch {
            let preview = String(data: raw.prefix(200), encoding: .utf8) ?? "<binary>"
            throw APIError.decodeFailed("[\(context)] \(error.localizedDescription) — response: \(preview)")
        }
        guard env.ok, let data = env.data else {
            throw APIError.httpError(0, "[\(context)] \(env.error ?? "Unknown API error")")
        }
        return data
    }

    private static func decodeEnvelopeRaw<T: Decodable>(_ type: T.Type, from raw: Data, context: String) throws -> T {
        let env: Envelope<T>
        do {
            env = try makeDecoder().decode(Envelope<T>.self, from: raw)
        } catch {
            let preview = String(data: raw.prefix(200), encoding: .utf8) ?? "<binary>"
            throw APIError.decodeFailed("[\(context)] \(error.localizedDescription) — response: \(preview)")
        }
        guard env.ok else {
            throw APIError.httpError(0, "[\(context)] \(env.error ?? "Unknown API error")")
        }
        // For mutation responses (update/delete) data may be nil — that's fine
        if let d = env.data { return d }
        guard let empty = "{}".data(using: .utf8),
              let fallback = try? makeDecoder().decode(T.self, from: empty) else {
            throw APIError.decodeFailed("[\(context)] Empty response data")
        }
        return fallback
    }

    // MARK: - Image upload

    struct ImageUploadResult: Decodable { var imagePath: String; var thumbPath: String? }

    static func uploadImage(serverURL: String, apiKey: String, photoId: Int, imageData: Data, mimeType: String) async throws -> ImageUploadResult {
        let trimmed = serverURL.trimmingCharacters(in: CharacterSet(charactersIn: "/ "))
        guard var comps = URLComponents(string: trimmed + "/darkroom-device-api.php") else { throw APIError.badURL }
        comps.queryItems = [
            URLQueryItem(name: "res",     value: "photo_image"),
            URLQueryItem(name: "id",      value: String(photoId)),
            URLQueryItem(name: "api_key", value: apiKey),
        ]
        guard let url = comps.url else { throw APIError.badURL }

        // Always send as JPEG — convert if needed
        let jpegData: Data
        if mimeType == "image/jpeg" {
            jpegData = imageData
        } else if let uiImg = UIImage(data: imageData), let compressed = uiImg.jpegData(compressionQuality: 0.88) {
            jpegData = compressed
        } else {
            jpegData = imageData
        }

        let boundary = "Boundary-\(UUID().uuidString)"
        var body = Data()
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"image\"; filename=\"photo.jpg\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(jpegData)
        body.append("\r\n--\(boundary)--\r\n".data(using: .utf8)!)

        var req = URLRequest(url: url, timeoutInterval: 90)
        req.httpMethod = "POST"
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        req.httpBody = body

        let (data, _): (Data, URLResponse)
        do {
            (data, _) = try await URLSession.shared.data(for: req)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        }
        let env = try makeDecoder().decode(Envelope<ImageUploadResult>.self, from: data)
        guard env.ok, let result = env.data else { throw APIError.httpError(0, env.error ?? "Upload failed") }
        return result
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
        var req = URLRequest(url: url, timeoutInterval: 30)
        req.httpMethod = method
        req.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body { req.httpBody = body; req.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        let (data, resp): (Data, URLResponse)
        do {
            (data, resp) = try await URLSession.shared.data(for: req)
        } catch is CancellationError {
            throw CancellationError()
        } catch let e as URLError {
            switch e.code {
            case .cancelled: throw CancellationError()
            case .notConnectedToInternet, .networkConnectionLost: throw APIError.networkError("No internet")
            case .timedOut: throw APIError.networkError("Request timed out")
            case .cannotFindHost, .cannotConnectToHost: throw APIError.networkError("Cannot reach server")
            default: throw APIError.networkError(e.localizedDescription)
            }
        }
        guard let http = resp as? HTTPURLResponse else { throw APIError.networkError("No HTTP response") }
        if http.statusCode == 401 { throw APIError.unauthorized }
        if http.statusCode >= 400 {
            let msg = String(data: data.prefix(300), encoding: .utf8) ?? "HTTP \(http.statusCode)"
            throw APIError.httpError(http.statusCode, msg)
        }
        return data
    }
}
