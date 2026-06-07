import Foundation

// MARK: - LibraryExercise
//
// Normalized exercise model for the GIF-backed exercise library.
// Named `LibraryExercise` to avoid colliding with the existing
// `Exercise` (TrainingModels) and `WorkoutExercise` (Models) types,
// which model AI-generated program entries (sets/reps), not the catalog.
//
// Mirrors the agreed schema:
//   { id, name, bodyPart, targetMuscle, equipment, gifUrl, instructions? }

struct LibraryExercise: Codable, Identifiable, Hashable {
    let id: String
    let name: String
    let bodyPart: String
    let targetMuscle: String
    let equipment: String
    let instructions: [String]
    let secondaryMuscles: [String]

    /// The current ExerciseDB API no longer returns a `gifUrl`; the animated
    /// demo is served from an authenticated image endpoint keyed by `id`.
    var gifUrl: String { ExerciseDBService.imageURL(for: id) }

    // ExerciseDB returns `target`; we normalize it to `targetMuscle`.
    enum CodingKeys: String, CodingKey {
        case id, name, bodyPart, equipment, instructions
        case targetMuscle = "target"
        case secondaryMuscles
    }

    init(
        id: String,
        name: String,
        bodyPart: String,
        targetMuscle: String,
        equipment: String,
        instructions: [String] = [],
        secondaryMuscles: [String] = []
    ) {
        self.id = id
        self.name = name
        self.bodyPart = bodyPart
        self.targetMuscle = targetMuscle
        self.equipment = equipment
        self.instructions = instructions
        self.secondaryMuscles = secondaryMuscles
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        // `id` is sometimes a number in third-party mirrors; decode defensively.
        if let s = try? c.decode(String.self, forKey: .id) {
            id = s
        } else if let i = try? c.decode(Int.self, forKey: .id) {
            id = "\(i)"
        } else {
            id = UUID().uuidString
        }
        name             = (try? c.decode(String.self, forKey: .name)) ?? "Unknown"
        bodyPart         = (try? c.decode(String.self, forKey: .bodyPart)) ?? ""
        targetMuscle     = (try? c.decode(String.self, forKey: .targetMuscle)) ?? ""
        equipment        = (try? c.decode(String.self, forKey: .equipment)) ?? ""
        instructions     = (try? c.decode([String].self, forKey: .instructions)) ?? []
        secondaryMuscles = (try? c.decode([String].self, forKey: .secondaryMuscles)) ?? []
    }
}

// MARK: - Display helpers

extension LibraryExercise {
    /// Title-cased name (ExerciseDB stores everything lowercase).
    var displayName: String { name.capitalized }

    /// Lowercased haystack used for local fuzzy search.
    var searchHaystack: String {
        ([name, bodyPart, targetMuscle, equipment] + secondaryMuscles)
            .joined(separator: " ")
            .lowercased()
    }
}
