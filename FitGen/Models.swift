import SwiftUI

// MARK: - Workout Program

struct WorkoutProgram: Codable {
    let days: [WorkoutDay]
}

struct WorkoutDay: Codable, Identifiable {
    var id: String { day }
    let day: String
    let focus: String
    let exercises: [WorkoutExercise]
}

struct WorkoutExercise: Codable {
    let name: String
    let sets: Int
    let reps: String
    let muscle: String
    let instructions: String

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, muscle, instructions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name         = try c.decode(String.self, forKey: .name)
        muscle       = try c.decode(String.self, forKey: .muscle)
        instructions = try c.decode(String.self, forKey: .instructions)

        // Robust sets: LLMs sometimes return "4" instead of 4
        if let i = try? c.decode(Int.self, forKey: .sets) {
            sets = i
        } else if let s = try? c.decode(String.self, forKey: .sets), let i = Int(s) {
            sets = i
        } else {
            sets = 3
        }

        // Robust reps: could be int or string like "8-12"
        if let i = try? c.decode(Int.self, forKey: .reps) {
            reps = "\(i)"
        } else {
            reps = (try? c.decode(String.self, forKey: .reps)) ?? "10"
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(name,         forKey: .name)
        try c.encode(sets,         forKey: .sets)
        try c.encode(reps,         forKey: .reps)
        try c.encode(muscle,       forKey: .muscle)
        try c.encode(instructions, forKey: .instructions)
    }
}

// MARK: - Chat

struct ChatMessage: Identifiable, Equatable {
    let id = UUID()
    let role: String    // "user" | "assistant"
    let content: String
}

// MARK: - Helpers

extension String {
    /// Maps a muscle group name to a display color.
    var muscleColor: Color {
        let l = lowercased()
        if l.contains("chest")                                                      { return .red    }
        if l.contains("back") || l.contains("lat")                                  { return .blue   }
        if l.contains("leg") || l.contains("quad") || l.contains("hamstring")
            || l.contains("glute") || l.contains("calf")                            { return .orange }
        if l.contains("shoulder") || l.contains("delt")                             { return .purple }
        if l.contains("arm") || l.contains("bicep") || l.contains("tricep")        { return .green  }
        if l.contains("core") || l.contains("ab")                                   { return .teal   }
        return .gray
    }
}
