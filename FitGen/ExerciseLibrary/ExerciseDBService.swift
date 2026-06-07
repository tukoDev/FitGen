import Foundation

// MARK: - ExerciseDBService
//
// Thin networking layer over ExerciseDB (RapidAPI).
// Follows the same shape as `GroqService`/`GeminiService`: a stateless
// struct with async static methods and keys read from `Constants`.
//
// API docs: https://rapidapi.com/justin-WFnsXH_t6/api/exercisedb
//   GET /exercises?limit=&offset=
//   GET /exercises/bodyPartList
//   GET /exercises/equipmentList
//   GET /exercises/name/{name}?limit=&offset=

enum ExerciseDBError: Error, LocalizedError {
    case missingAPIKey
    case badResponse(Int)
    case decodingFailed
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:      return "ExerciseDB API key is not configured."
        case .badResponse(let c): return "ExerciseDB returned HTTP \(c)."
        case .decodingFailed:     return "Could not decode the exercise data."
        case .transport(let m):   return m
        }
    }
}

struct ExerciseDBService {

    private static let host = "exercisedb.p.rapidapi.com"
    private static let base = "https://exercisedb.p.rapidapi.com"

    /// The free ExerciseDB plan caps every page at 10 items regardless of the
    /// requested `limit`, so paginate in steps of 10 via `offset`.
    static let pageSize = 10

    // MARK: Public API

    /// Fetches a single page of the full catalog.
    static func fetchPage(limit: Int = 10, offset: Int) async throws -> [LibraryExercise] {
        let url = makeURL("/exercises", query: [
            URLQueryItem(name: "limit",  value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ])
        return try await fetch([LibraryExercise].self, from: url)
    }

    /// Server-side search by name. Returns all matches (ExerciseDB caps internally).
    static func search(name: String, limit: Int = 10, offset: Int = 0) async throws -> [LibraryExercise] {
        let q = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let encoded = q.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? q
        let url = makeURL("/exercises/name/\(encoded)", query: [
            URLQueryItem(name: "limit",  value: "\(limit)"),
            URLQueryItem(name: "offset", value: "\(offset)")
        ])
        return try await fetch([LibraryExercise].self, from: url)
    }

    /// Available filter values, used to populate the filter UI.
    static func bodyPartList() async throws -> [String] {
        try await fetch([String].self, from: makeURL("/exercises/bodyPartList"))
    }

    static func equipmentList() async throws -> [String] {
        try await fetch([String].self, from: makeURL("/exercises/equipmentList"))
    }

    /// URL of the animated GIF for an exercise. This endpoint requires the
    /// RapidAPI auth headers, which `ExerciseImageLoader` injects into the
    /// SDWebImage downloader. Valid resolutions: 180, 360, 720, 1080.
    static func imageURL(for id: String, resolution: Int = 360) -> String {
        "\(base)/image?resolution=\(resolution)&exerciseId=\(id)"
    }

    /// Host used to scope the auth-header injection for image requests.
    static var imageHost: String { host }

    // MARK: - Private

    private static func makeURL(_ path: String, query: [URLQueryItem] = []) -> URL {
        var comps = URLComponents(string: base + path)!
        if !query.isEmpty { comps.queryItems = query }
        return comps.url!
    }

    private static func fetch<T: Decodable>(_ type: T.Type, from url: URL) async throws -> T {
        let key = Constants.exerciseDBAPIKey
        guard !key.isEmpty, key != "YOUR_RAPIDAPI_KEY" else {
            throw ExerciseDBError.missingAPIKey
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(key,  forHTTPHeaderField: "X-RapidAPI-Key")
        request.setValue(host, forHTTPHeaderField: "X-RapidAPI-Host")
        request.timeoutInterval = 20

        // The free plan rate-limits bursts (403/429); retry a couple of times
        // with exponential backoff before giving up.
        var attempt = 0
        while true {
            do {
                let (data, response) = try await URLSession.shared.data(for: request)
                if let http = response as? HTTPURLResponse {
                    let code = http.statusCode
                    if code == 429 || code == 403, attempt < 3 {
                        attempt += 1
                        try? await Task.sleep(nanoseconds: UInt64(attempt) * 800_000_000)
                        continue
                    }
                    if !(200...299).contains(code) {
                        throw ExerciseDBError.badResponse(code)
                    }
                }
                do {
                    return try JSONDecoder().decode(T.self, from: data)
                } catch {
                    throw ExerciseDBError.decodingFailed
                }
            } catch let e as ExerciseDBError {
                throw e
            } catch {
                if attempt < 3 {
                    attempt += 1
                    try? await Task.sleep(nanoseconds: UInt64(attempt) * 800_000_000)
                    continue
                }
                throw ExerciseDBError.transport(error.localizedDescription)
            }
        }
    }
}
