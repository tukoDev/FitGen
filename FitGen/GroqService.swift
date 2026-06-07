import Foundation

struct GroqService {

    // MARK: - Chat

    static func chat(messages: [ChatMessage], systemPrompt: String) async -> String {
        var payload: [[String: String]] = [["role": "system", "content": systemPrompt]]
        for m in messages { payload.append(["role": m.role, "content": m.content]) }
        return await callAPI(messages: payload)
    }

    // MARK: - Training Program Generation (TrainingProgram model)

    static func generateTrainingProgram(profile: UserFitnessProfile) async throws -> TrainingProgram {
        let prompt = """
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

        let payload: [[String: String]] = [
            ["role": "system", "content": "You are a professional fitness program designer. Always respond with valid JSON only. No explanation, no markdown."],
            ["role": "user",   "content": prompt]
        ]

        let raw = await callAPI(messages: payload, jsonMode: true)
        let jsonString = extractJSON(from: raw)

        guard let data = jsonString.data(using: .utf8) else {
            throw GeminiError.decodingFailed
        }
        do {
            return try JSONDecoder().decode(TrainingProgram.self, from: data)
        } catch {
            print("[Groq] TrainingProgram decode error: \(error)")
            print("[Groq] Raw JSON: \(jsonString.prefix(500))")
            throw GeminiError.decodingFailed
        }
    }

    // MARK: - Program Generation

    static func generateProgram(
        name: String, age: Int, weight: Double,
        height: Double, goal: String, activityLevel: String
    ) async -> String {
        let prompt = """
        Generate a personalized 6-day weekly workout program for:
        Name: \(name), Age: \(age), Weight: \(weight)kg, Height: \(height)cm
        Goal: \(goal), Activity Level: \(activityLevel)

        Return ONLY a valid JSON object — no markdown, no code blocks, no explanation.
        Use exactly this structure:
        {"days":[{"day":"Monday","focus":"Chest & Triceps","exercises":[{"name":"Bench Press","sets":4,"reps":"8-12","muscle":"Chest","instructions":"Lie flat on bench. Grip bar slightly wider than shoulder-width. Lower to mid-chest under control. Press up explosively and repeat."}]}]}

        Rules:
        - Exactly 6 days: Monday through Saturday
        - 4-5 exercises per day
        - sets must be an integer (e.g. 4)
        - reps must be a string range (e.g. "8-12" or "12")
        - instructions: 3 clear, numbered-style sentences
        - Tailor intensity and volume to the goal and activity level
        - Cover all major muscle groups across the week
        """

        let payload: [[String: String]] = [
            ["role": "system", "content": "You are a professional fitness program designer. Always respond with valid JSON only. No explanation, no markdown."],
            ["role": "user",   "content": prompt]
        ]

        let raw = await callAPI(messages: payload)
        return extractJSON(from: raw)
    }

    // MARK: - Private

    private static func callAPI(messages: [[String: String]], jsonMode: Bool = false) async -> String {
        let url = URL(string: "https://api.groq.com/openai/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json",               forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(Constants.groqAPIKey)", forHTTPHeaderField: "Authorization")

        var body: [String: Any] = [
            "model":    "llama-3.3-70b-versatile",
            "messages": messages
        ]
        if jsonMode {
            body["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (data, response) = try await URLSession.shared.data(for: request)

            if let http = response as? HTTPURLResponse {
                print("[Groq] HTTP \(http.statusCode)")
            }
            if let preview = String(data: data, encoding: .utf8) {
                print("[Groq] Response preview: \(preview.prefix(400))")
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return "Error: Could not parse API response"
            }
            if let err = json["error"] as? [String: Any] {
                return "Error: \(err["message"] as? String ?? "Unknown API error")"
            }
            guard
                let choices = json["choices"]  as? [[String: Any]],
                let message = choices.first?["message"] as? [String: Any],
                let content = message["content"] as? String
            else { return "Error: Unexpected response format" }

            return content
        } catch {
            return "Error: \(error.localizedDescription)"
        }
    }

    /// Strips markdown code fences and extracts the outermost JSON object.
    private static func extractJSON(from text: String) -> String {
        var s = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Remove ```json ... ``` or ``` ... ```
        if s.hasPrefix("```") {
            s = s.components(separatedBy: "\n").dropFirst().joined(separator: "\n")
            if s.hasSuffix("```") { s = String(s.dropLast(3)) }
            s = s.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        // Find the outermost { ... }
        if let start = s.firstIndex(of: "{"), let end = s.lastIndex(of: "}") {
            return String(s[start...end])
        }
        return s
    }
}
