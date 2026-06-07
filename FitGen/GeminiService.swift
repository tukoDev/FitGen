import Foundation

// MARK: - Error

enum GeminiError: Error, LocalizedError {
    case invalidResponse
    case decodingFailed
    case apiError(String)
    case rateLimited

    var errorDescription: String? {
        switch self {
        case .invalidResponse:   return "Gemini'den geçersiz yanıt alındı."
        case .decodingFailed:    return "Program verisi çözümlenemedi."
        case .apiError(let msg): return "API hatası: \(msg)"
        case .rateLimited:       return "İstek limiti aşıldı. Lütfen bekleyip tekrar deneyin."
        }
    }
}

// MARK: - Service

struct GeminiService {

    private static let endpoint = "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent"

    func generateProgram(profile: UserFitnessProfile) async throws -> TrainingProgram {
        var lastError: Error = GeminiError.apiError("Max retries exceeded")

        for attempt in 1...3 {
            do {
                print("[Gemini] generateProgram called (attempt \(attempt))")
                return try await performRequest(profile: profile)
            } catch GeminiError.rateLimited {
                print("[Gemini] Rate limited, waiting \(attempt * 5)s...")
                try await Task.sleep(nanoseconds: UInt64(attempt * 5) * 1_000_000_000)
                lastError = GeminiError.rateLimited
            }
        }
        throw lastError
    }

    private func performRequest(profile: UserFitnessProfile) async throws -> TrainingProgram {
        guard var components = URLComponents(string: GeminiService.endpoint) else {
            throw GeminiError.invalidResponse
        }
        components.queryItems = [URLQueryItem(name: "key", value: Constants.geminiAPIKey)]
        guard let url = components.url else { throw GeminiError.invalidResponse }

        let body: [String: Any] = [
            "contents": [["parts": [["text": buildPrompt(for: profile)]]]]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        if let http = response as? HTTPURLResponse {
            print("[Gemini] HTTP status:", http.statusCode)
            if http.statusCode == 429 {
                let errorBody = String(data: data, encoding: .utf8) ?? "no body"
                print("[Gemini] 429 body:", errorBody)
                throw GeminiError.rateLimited
            }
            if http.statusCode != 200 {
                if let errJson = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let errObj  = errJson["error"] as? [String: Any],
                   let message = errObj["message"] as? String {
                    throw GeminiError.apiError(message)
                }
                throw GeminiError.apiError("HTTP \(http.statusCode)")
            }
        }

        let text = try extractText(from: data)
        let jsonString = extractJSON(from: text)

        guard let jsonData = jsonString.data(using: .utf8) else {
            throw GeminiError.decodingFailed
        }

        do {
            return try JSONDecoder().decode(TrainingProgram.self, from: jsonData)
        } catch {
            print("[Gemini] Decode error: \(error)")
            throw GeminiError.decodingFailed
        }
    }

    // MARK: - Private

    private func buildPrompt(for profile: UserFitnessProfile) -> String {
        """
        Return ONLY valid JSON, no markdown, no code blocks, no explanation.
        Schema:
        {
          "id": "string (uuid)",
          "name": "string (program name)",
          "durationWeeks": number,
          "days": [
            {
              "id": "string (uuid)",
              "name": "string (e.g. Push, Pull, Legs)",
              "exercises": [
                {
                  "id": "string (uuid)",
                  "name": "string",
                  "sets": number,
                  "reps": "string (e.g. '8-12')",
                  "restSeconds": number,
                  "notes": "string or null"
                }
              ]
            }
          ]
        }

        Create a training program for:
        - Goal: \(profile.goal)
        - Level: \(profile.level.rawValue)
        - Training days per week: \(profile.daysPerWeek)
        - Duration: choose an appropriate number of weeks (4–12)

        Rules:
        - Exactly \(profile.daysPerWeek) training days in the "days" array
        - 4–6 exercises per day
        - All ids must be unique UUID strings
        - Tailor intensity and volume to the level and goal
        """
    }

    private func extractText(from data: Data) throws -> String {
        guard
            let json      = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let candidates = json["candidates"] as? [[String: Any]],
            let content   = candidates.first?["content"] as? [String: Any],
            let parts     = content["parts"] as? [[String: Any]],
            let text      = parts.first?["text"] as? String
        else { throw GeminiError.invalidResponse }
        return text
    }

    private func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.hasPrefix("```") {
            s = s.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if s.hasSuffix("```") { s = String(s.dropLast(3)) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s
    }
}
